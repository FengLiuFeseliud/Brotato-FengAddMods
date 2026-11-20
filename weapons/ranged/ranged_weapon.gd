extends "res://weapons/ranged/ranged_weapon.gd"


# ============================================================
# 通用远程武器类：按攻击次数触发动作
#   场景根节点使用本脚本，并通过 actions 数组直接传入动作资源（.tres）。
#   每个动作自带触发次数、重复规则与参数；本类只负责调度。
#   动作可影响：是否禁止普通攻击、是否计入攻击次数、动画速度与冷却。
#   trigger_count <= 0 的动作在初始化时直接常驻激活。
# ============================================================

export(Array, Resource) var actions = []

var _fengliu_action_entries := []
var _fengliu_active_actions := []
var _fengliu_normal_attack_count := 0


func _ready() -> void:
	._ready()
	_fengliu_init_actions()


# 投射物生成：先走原版连接，再把事件转给当前激活的远程动作
func on_projectile_shot(projectile: Node2D) -> void:
	.on_projectile_shot(projectile)

	if _fengliu_active_actions.empty() or not is_instance_valid(projectile):
		return

	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action) and action.fengliu_is_ranged_action():
			action.fengliu_on_projectile_shot(projectile)

	if projectile.has_signal("hit_something") and not projectile.is_connected("hit_something", self, "_fengliu_on_action_projectile_hit"):
		var _error = projectile.connect("hit_something", self, "_fengliu_on_action_projectile_hit", [projectile])


# 投射物命中：转发给当前激活的远程动作
func _fengliu_on_action_projectile_hit(thing_hit, damage_dealt, projectile) -> void:
	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action) and action.fengliu_is_ranged_action():
			action.fengliu_on_projectile_hit(thing_hit, damage_dealt, projectile)


func _fengliu_init_actions() -> void:
	for action_resource in actions:
		if action_resource == null or not (action_resource is Resource):
			continue

		if not action_resource.has_method("fengliu_is_ranged_action"):
			push_warning("actions contains a non-ranged action: %s" % str(action_resource))
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
	if _fengliu_any_action_takes_over_physics():
		return

	._physics_process(delta)
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


func should_shoot() -> bool:
	if _fengliu_any_action_blocks_shoot():
		return false
	return .should_shoot()


func shoot() -> void:
	if _fengliu_any_action_blocks_shoot():
		return

	if _fengliu_should_count_attack():
		_fengliu_normal_attack_count += 1

	var animation_multiplier: float = _fengliu_get_animation_speed_multiplier()
	var saved_animation_speed = null
	if "animation_speed" in current_stats:
		saved_animation_speed = current_stats.animation_speed
		if not is_equal_approx(animation_multiplier, 1.0):
			current_stats.animation_speed = saved_animation_speed * animation_multiplier

	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_before_shoot()

	.shoot()

	for action in _fengliu_active_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_after_shoot()

	if saved_animation_speed != null:
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


# 供动作调用：把当前冷却压缩到“考虑动作后的冷却”，让触发后的第一下尽快开始
func fengliu_shorten_current_cooldown() -> void:
	if _is_shooting:
		return
	_current_cooldown = min(_current_cooldown, get_next_cooldown())


func fengliu_get_player():
	return _parent


func fengliu_get_weapon_stats():
	return current_stats
