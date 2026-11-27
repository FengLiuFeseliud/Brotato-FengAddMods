extends "res://weapons/ranged/ranged_weapon.gd"


# ============================================================
# 通用远程武器类：按攻击次数触发动作
#   场景根节点使用本脚本，并通过 actions 数组直接传入动作资源（.tres）。
#   每个动作自带触发次数、重复规则与参数；本类只负责调度。
#   动作可影响：是否禁止普通攻击、是否计入攻击次数、动画速度与冷却。
#   trigger_count <= 0 的动作在初始化时直接常驻激活。
# ============================================================

export(Array, Resource) var actions = []

const ACTION_SCHEDULER = preload("res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/action_scheduler.gd")

var _fengliu_action_scheduler = null


func _ready() -> void:
	._ready()
	_fengliu_init_actions()


# 投射物生成：先走原版连接，再把事件转给当前激活的远程动作
func on_projectile_shot(projectile: Node2D) -> void:
	.on_projectile_shot(projectile)

	if _fengliu_action_scheduler == null or not is_instance_valid(projectile):
		return

	var active_actions = _fengliu_action_scheduler.get_active_actions()
	if active_actions.empty():
		return

	# 动作可能在炮弹命中前结束，快照保证命中回调仍能转给发射时动作
	_fengliu_action_scheduler.store_actions_on_projectile(projectile, active_actions)
	for action in active_actions:
		if action != null and is_instance_valid(action) and action.fengliu_is_ranged_action():
			action.fengliu_on_projectile_shot(projectile)

	if projectile.has_signal("hit_something") and not projectile.is_connected("hit_something", self, "_fengliu_on_action_projectile_hit"):
		var _error = projectile.connect("hit_something", self, "_fengliu_on_action_projectile_hit", [projectile])


# 投射物命中：优先使用发射时快照，避免动作在飞行途中结束导致命中丢失
func _fengliu_on_action_projectile_hit(thing_hit, damage_dealt, projectile) -> void:
	if _fengliu_action_scheduler == null:
		return

	var actions = _fengliu_action_scheduler.get_actions_from_projectile(projectile)
	if actions.empty():
		actions = _fengliu_action_scheduler.get_active_actions()

	for action in actions:
		if action != null and is_instance_valid(action) and action.fengliu_is_ranged_action():
			action.fengliu_on_projectile_hit(thing_hit, damage_dealt, projectile)


func _fengliu_init_actions() -> void:
	if _fengliu_action_scheduler == null:
		_fengliu_action_scheduler = ACTION_SCHEDULER.new()
	_fengliu_action_scheduler.setup(self, actions)


func _physics_process(delta: float) -> void:
	if _fengliu_should_stop_actions():
		if _fengliu_action_scheduler != null:
			_fengliu_action_scheduler.stop_all()
		._physics_process(delta)
		return

	if _fengliu_action_scheduler != null:
		_fengliu_action_scheduler.update(delta)
		if _fengliu_action_scheduler.any_action_takes_over_physics():
			return

		# 先检查触发：极短冷却武器在射击结束后可能立即进入下一次射击，
		# 放在父类之后会因 _is_shooting 再次为 true 而错过触发
		if not _is_shooting:
			_fengliu_action_scheduler.check_triggers()

	._physics_process(delta)


func _process(delta: float) -> void:
	._process(delta)

	if _fengliu_action_scheduler == null:
		return

	for action in _fengliu_action_scheduler.get_active_actions():
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
	if _fengliu_action_scheduler != null:
		_fengliu_action_scheduler.update(delta)


func _fengliu_stop_all_actions() -> void:
	if _fengliu_action_scheduler != null:
		_fengliu_action_scheduler.stop_all()


func _fengliu_check_action_triggers() -> void:
	if _fengliu_action_scheduler == null:
		return

	if _is_shooting:
		return

	if weapon_pos < 0:
		return

	if _parent == null or not is_instance_valid(_parent):
		return

	if "dead" in _parent and _parent.dead:
		return

	_fengliu_action_scheduler.check_triggers()

func should_shoot() -> bool:
	if _fengliu_action_scheduler != null:
		if _fengliu_action_scheduler.should_block_shoot():
			if _fengliu_action_scheduler.get_takeover_action() == null:
				return false

	return .should_shoot()


func shoot() -> void:
	if _fengliu_action_scheduler == null:
		.shoot()
		return

	var takeover_action = _fengliu_action_scheduler.get_takeover_action()
	if takeover_action != null:
		_nb_shots_taken += 1
		if _fengliu_action_scheduler.should_count_attack():
			_fengliu_action_scheduler.register_normal_attack()
		takeover_action.fengliu_take_over_shoot()
		_current_cooldown = get_next_cooldown()
		_fengliu_action_scheduler.finish_takeover(takeover_action)
		set_shooting(false)
		return

	if _fengliu_action_scheduler.should_block_shoot():
		return

	if _fengliu_action_scheduler.should_count_attack():
		_fengliu_action_scheduler.register_normal_attack()

	var active_actions = _fengliu_action_scheduler.get_active_actions()
	var animation_multiplier: float = _fengliu_action_scheduler.get_animation_speed_multiplier()
	var saved_animation_speed = null
	if "animation_speed" in current_stats:
		saved_animation_speed = current_stats.animation_speed
		if not is_equal_approx(animation_multiplier, 1.0):
			current_stats.animation_speed = saved_animation_speed * animation_multiplier

	for action in active_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_before_shoot()

	.shoot()

	for action in active_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_after_shoot()

	if saved_animation_speed != null:
		current_stats.animation_speed = saved_animation_speed


func get_next_cooldown(at_wave_begin: bool = false) -> float:
	var cooldown: float = .get_next_cooldown(at_wave_begin)
	if at_wave_begin or _fengliu_action_scheduler == null:
		return cooldown

	cooldown = _fengliu_action_scheduler.modify_cooldown(cooldown)
	return max(1.0, cooldown)

func _fengliu_get_take_over_shoot_action():
	if _fengliu_action_scheduler != null:
		return _fengliu_action_scheduler.get_takeover_action()
	return null


func _fengliu_finish_take_over_action(action) -> void:
	if _fengliu_action_scheduler != null:
		_fengliu_action_scheduler.finish_takeover(action)


func _fengliu_any_action_blocks_shoot() -> bool:
	if _fengliu_action_scheduler == null:
		return false
	return _fengliu_action_scheduler.should_block_shoot()


func _fengliu_any_action_takes_over_physics() -> bool:
	if _fengliu_action_scheduler == null:
		return false
	return _fengliu_action_scheduler.any_action_takes_over_physics()


func _fengliu_any_action_takes_over_process() -> bool:
	if _fengliu_action_scheduler == null:
		return false
	return _fengliu_action_scheduler.any_action_takes_over_process()


func _fengliu_should_count_attack() -> bool:
	if _fengliu_action_scheduler == null:
		return true
	return _fengliu_action_scheduler.should_count_attack()


func _fengliu_get_animation_speed_multiplier() -> float:
	if _fengliu_action_scheduler == null:
		return 1.0
	return _fengliu_action_scheduler.get_animation_speed_multiplier()


# 供动作调用：把当前冷却压缩到“考虑动作后的冷却”，让触发后的第一下尽快开始
func fengliu_shorten_current_cooldown() -> void:
	if _is_shooting:
		return
	_current_cooldown = min(_current_cooldown, get_next_cooldown())


func fengliu_get_player():
	return _parent


func fengliu_get_weapon_stats():
	return current_stats


# ---- 动作宿主接口：供 ranged_action 与共享 scheduler 使用 ----

func fengliu_get_action_stats():
	return current_stats


func fengliu_get_action_base_projectiles() -> int:
	if stats != null and "nb_projectiles" in stats:
		return int(max(0, int(stats.nb_projectiles)))
	return 0


func fengliu_get_action_muzzle_position() -> Vector2:
	if is_instance_valid(muzzle):
		return muzzle.global_position
	return global_position


func fengliu_get_action_shoot_rotation() -> float:
	return rotation


func fengliu_get_action_attack_id() -> int:
	if _shooting_behavior != null and _shooting_behavior.has_method("_get_next_attack_id"):
		return int(_shooting_behavior._get_next_attack_id())
	return -1


func fengliu_get_action_damage_tracking_key() -> int:
	return damage_tracking_key_hash


func fengliu_get_action_from_node():
	return self


func fengliu_on_action_projectile_shot(projectile) -> void:
	on_projectile_shot(projectile)

