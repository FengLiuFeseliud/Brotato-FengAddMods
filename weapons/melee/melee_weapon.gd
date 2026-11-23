extends "res://weapons/melee/melee_weapon.gd"



# ============================================================
# 通用近战武器类：按攻击次数触发动作
#   场景根节点使用本脚本，并通过 actions 数组直接传入动作资源（.tres）。
#   每个动作自带触发次数、重复规则与参数；本类只负责调度。
#   动作可影响：是否禁止普通攻击、是否计入攻击次数、攻击类型、动画速度与冷却。
#   动作还可强制无目标/移动中开火，并锁定触发瞬间的武器朝向。
#   trigger_count <= 0 的动作在初始化时直接常驻激活。
# ============================================================

export(Array, Resource) var actions = []

var _fengliu_action_entries := []
var _fengliu_active_actions := []
var _fengliu_normal_attack_count := 0
var _fengliu_attack_type_overridden := false
var _fengliu_attack_range_override := 0


func _ready() -> void:
	._ready()
	_fengliu_init_actions()


func init_stats(at_wave_begin: bool = true) -> void:
	.init_stats(at_wave_begin)
	_fengliu_notify_stats_initialized()


func _fengliu_notify_stats_initialized() -> void:
	for entry in _fengliu_action_entries:
		var action = entry["action"]
		if action == null or not is_instance_valid(action):
			continue

		if action.has_method("fengliu_on_weapon_stats_initialized"):
			action.fengliu_on_weapon_stats_initialized()


func _fengliu_init_actions() -> void:
	for action_resource in actions:
		if action_resource == null or not (action_resource is Resource):
			continue

		if not action_resource.has_method("fengliu_is_melee_action"):
			push_warning("actions contains a non-melee action: %s" % str(action_resource))
			continue

		# 每把武器使用独立的动作实例，避免多把武器共享计时与状态
		var action = action_resource.duplicate()
		if action == null:
			continue
		action.fengliu_setup(self)
		_fengliu_action_entries.push_back({
			"action": action,
			"last_trigger_count": -1,
			"fired": false,
		})

	_fengliu_start_always_active_actions()


func _fengliu_start_always_active_actions() -> void:
	for entry in _fengliu_action_entries:
		var action = entry["action"]
		if action == null or not is_instance_valid(action):
			continue

		if action.fengliu_get_trigger_count() > 0:
			continue

		_fengliu_active_actions.push_back(action)
		action.fengliu_start()


func _physics_process(delta: float) -> void:
	if _fengliu_should_stop_actions():
		_fengliu_stop_all_actions()
		._physics_process(delta)
		return

	_fengliu_update_actions(delta)
	_fengliu_update_passive_actions(delta)

	if _fengliu_any_action_takes_over_physics():
		_fengliu_sync_attack_type_override()
		return

	._physics_process(delta)
	_fengliu_sync_action_aim_targets()
	_fengliu_apply_rotation_lock()
	_fengliu_check_action_triggers()


func _process(delta: float) -> void:
	._process(delta)

	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action) and action.fengliu_should_take_over_process():
			action.fengliu_process(delta)


func _fengliu_should_stop_actions() -> bool:
	if weapon_pos < 0:
		return true

	if _parent == null or not is_instance_valid(_parent):
		return true

	if "dead" in _parent and _parent.dead:
		return true

	return false


func _fengliu_update_actions(delta: float) -> void:
	for i in range(_fengliu_active_actions.size() - 1, -1, -1):
		var action = _fengliu_active_actions[i]
		if action == null or not is_instance_valid(action):
			_fengliu_active_actions.remove(i)
			continue

		action.fengliu_update(delta)
		if action.fengliu_is_finished():
			action.fengliu_finish()
			_fengliu_active_actions.remove(i)

	_fengliu_sync_attack_type_override()


func _fengliu_stop_all_actions() -> void:
	var remaining_actions := []
	for action in _fengliu_active_actions:
		if action == null or not is_instance_valid(action):
			continue

		# trigger_count <= 0 表示常驻激活，停止武器时保留
		if action.fengliu_get_trigger_count() <= 0:
			remaining_actions.push_back(action)
			continue

		action.fengliu_finish()

	_fengliu_active_actions = remaining_actions
	_fengliu_sync_attack_type_override()


func _fengliu_check_action_triggers() -> void:
	if _fengliu_normal_attack_count <= 0:
		return

	if _is_shooting:
		return

	if weapon_pos < 0:
		return

	if _parent == null or not is_instance_valid(_parent):
		return

	if "dead" in _parent and _parent.dead:
		return

	for entry in _fengliu_action_entries:
		var action = entry["action"]
		if action == null or not is_instance_valid(action):
			continue

		if entry["fired"] and not action.fengliu_should_repeat():
			continue

		var first_trigger_count: int = action.fengliu_get_trigger_count()
		if first_trigger_count <= 0:
			continue

		if _fengliu_normal_attack_count < first_trigger_count:
			continue

		var trigger_interval: int = action.fengliu_get_trigger_interval()
		if trigger_interval <= 0:
			trigger_interval = first_trigger_count

		if (_fengliu_normal_attack_count - first_trigger_count) % trigger_interval != 0:
			continue

		if entry["last_trigger_count"] == _fengliu_normal_attack_count:
			continue
			
		if not action.fengliu_can_start():
			continue

		entry["last_trigger_count"] = _fengliu_normal_attack_count
		if not action.fengliu_should_repeat():
			entry["fired"] = true
		# 先加入激活列表，动作启动时读取的冷却/倍率才会包含自己
		_fengliu_active_actions.push_back(action)
		action.fengliu_start()

	_fengliu_sync_attack_type_override()


func on_weapon_hit_something(thing_hit: Node, damage_dealt: int, hitbox: Hitbox) -> void:
	.on_weapon_hit_something(thing_hit, damage_dealt, hitbox)

	if hitbox != _hitbox:
		return

	for action in _fengliu_active_actions:
		if action == null or not is_instance_valid(action):
			continue

		if action.has_method("fengliu_on_hit"):
			action.fengliu_on_hit(thing_hit, damage_dealt)


func should_shoot() -> bool:
	if _fengliu_any_action_blocks_shoot():
		return false

	if _fengliu_any_action_forces_shoot():
		if _is_shooting:
			return false

		if weapon_pos < 0:
			return false

		if _parent == null or not is_instance_valid(_parent):
			return false

		if "cleaning_up" in _parent and _parent.cleaning_up:
			return false

		return _current_cooldown <= 0

	if _fengliu_attack_range_override <= 0 or current_stats == null:
		return .should_shoot()

	var original_max_range: int = current_stats.max_range
	current_stats.max_range = _fengliu_attack_range_override
	var result: bool = .should_shoot()
	current_stats.max_range = original_max_range
	return result


func shoot() -> void:
	if _fengliu_any_action_blocks_shoot():
		return

	_fengliu_sync_attack_type_override()
	if _fengliu_should_count_attack():
		_fengliu_normal_attack_count += 1

	var animation_multiplier: float = _fengliu_get_animation_speed_multiplier()
	var saved_animation_speed: float = current_stats.animation_speed
	if not is_equal_approx(animation_multiplier, 1.0):
		current_stats.animation_speed = saved_animation_speed * animation_multiplier

	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_before_shoot()

	.shoot()
	_fengliu_apply_rotation_lock()

	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_after_shoot()

	_fengliu_call_passive_after_shoot()

	current_stats.animation_speed = saved_animation_speed


func get_next_cooldown(at_wave_begin: bool = false) -> float:
	var cooldown: float = .get_next_cooldown(at_wave_begin)
	if at_wave_begin or _fengliu_active_actions.empty():
		return cooldown

	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action):
			cooldown = action.fengliu_modify_cooldown(cooldown)

	return max(1.0, cooldown)


func _fengliu_any_action_blocks_shoot() -> bool:
	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action) and action.fengliu_should_block_shoot():
			return true
	return false


func _fengliu_any_action_forces_shoot() -> bool:
	for action in _fengliu_active_actions:
		if action == null or not is_instance_valid(action):
			continue

		if action.has_method("fengliu_should_force_shoot") and action.fengliu_should_force_shoot():
			return true

	return false


func _fengliu_apply_rotation_lock() -> void:
	for action in _fengliu_active_actions:
		if action == null or not is_instance_valid(action):
			continue

		if not action.has_method("fengliu_should_lock_rotation") or not action.fengliu_should_lock_rotation():
			continue

		if action.has_method("fengliu_get_locked_rotation"):
			rotation = action.fengliu_get_locked_rotation()
		return


func _fengliu_sync_action_aim_targets() -> void:
	for action in _fengliu_active_actions:
		if action == null or not is_instance_valid(action):
			continue

		if action.has_method("fengliu_sync_aim_target"):
			action.fengliu_sync_aim_target()


func fengliu_get_aim_target():
	if _targets_in_range.size() == 0 or current_stats == null:
		return null

	var nearest = Utils.get_nearest_no_max(_targets_in_range, global_position, current_stats.min_range)
	if nearest.size() == 0:
		return null

	var target = nearest[0]
	if target == null or not is_instance_valid(target):
		return null

	return target


func fengliu_get_target_direction(target) -> float:
	if target == null or not is_instance_valid(target):
		return rotation

	return (Utils.get_target_position(target, global_position) - global_position).angle()


func _fengliu_update_passive_actions(delta: float) -> void:
	for entry in _fengliu_action_entries:
		var action = entry["action"]
		if action == null or not is_instance_valid(action):
			continue
		if action.has_method("fengliu_on_passive_physics_process"):
			action.fengliu_on_passive_physics_process(delta)


func _fengliu_call_passive_after_shoot() -> void:
	for entry in _fengliu_action_entries:
		var action = entry["action"]
		if action == null or not is_instance_valid(action):
			continue
		if action.has_method("fengliu_on_passive_after_shoot"):
			action.fengliu_on_passive_after_shoot()


# 供被动动作覆盖索敌/开火判定；面板与挥击保持原射程
func fengliu_set_attack_range_override(value: int) -> void:
	_fengliu_attack_range_override = value

	if _range_shape == null or not (_range_shape.shape is CircleShape2D):
		return

	var target_radius: float = float(value) + DETECTION_RANGE
	if is_equal_approx(_range_shape.shape.radius, target_radius):
		return

	var shape = _range_shape.shape.duplicate()
	shape.radius = target_radius
	_range_shape.shape = shape


func _fengliu_any_action_takes_over_physics() -> bool:
	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action) and action.fengliu_should_take_over_physics():
			return true
	return false


func _fengliu_any_action_takes_over_process() -> bool:
	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action) and action.fengliu_should_take_over_process():
			return true
	return false


func _fengliu_should_count_attack() -> bool:
	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action) and not action.fengliu_should_count_as_attack():
			return false
	return true


func _fengliu_get_animation_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action):
			multiplier *= max(0.01, action.fengliu_get_animation_speed_multiplier())
	return max(0.01, multiplier)


func _fengliu_get_attack_type_override() -> int:
	var attack_type: int = -1
	for action in _fengliu_active_actions:
		if action == null or not is_instance_valid(action):
			continue
		var action_attack_type: int = action.fengliu_get_attack_type_override()
		if action_attack_type >= 0:
			attack_type = action_attack_type
	return attack_type


func _fengliu_sync_attack_type_override() -> void:
	if stats == null:
		return

	var attack_type: int = _fengliu_get_attack_type_override()
	if attack_type >= 0:
		next_attack_type = attack_type
		_fengliu_attack_type_overridden = true
	elif _fengliu_attack_type_overridden:
		next_attack_type = stats.attack_type
		_fengliu_attack_type_overridden = false


# 供动作调用：把当前冷却压缩到“考虑动作后的冷却”，让触发后的第一下尽快开始
func fengliu_shorten_current_cooldown() -> void:
	if _is_shooting:
		return
	_current_cooldown = min(_current_cooldown, get_next_cooldown())


func fengliu_get_player():
	return _parent


func fengliu_get_weapon_stats():
	return current_stats
