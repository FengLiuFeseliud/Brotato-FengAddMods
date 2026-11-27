extends "res://entities/structures/turret/builder/builder_turret.gd"


const ACTION_SCHEDULER = preload("res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/action_scheduler.gd")

var _fengliu_action_scheduler = null
var _fengliu_attack_id: int = 0


# 扩展设置炮塔数据：base 内部先写 _current_weapon_ref，再调用父级 set_data
func set_data(data: Resource) -> void:
	.set_data(data)
	fengliu_sync_turret_actions()


# ============================================================
# 通用动作桥接：读取被复制武器场景的 actions
#   常驻动作与触发型动作统一交给共享 scheduler。
# ============================================================

func fengliu_sync_turret_actions() -> void:
	if _fengliu_action_scheduler == null:
		_fengliu_action_scheduler = ACTION_SCHEDULER.new()

	var action_resources: Array = []
	var weapon_ref = get("_current_weapon_ref")
	if weapon_ref != null and weapon_ref.has_method("fengliu_get_actions"):
		var actions = weapon_ref.fengliu_get_actions()
		if actions is Array:
			action_resources = actions

	# setup() 会重建动作实例；重新同步时清空旧触发状态
	_fengliu_action_scheduler.setup(self, action_resources)


func _physics_process(delta: float) -> void:
	if _fengliu_action_scheduler != null:
		_fengliu_action_scheduler.update(delta)
		if not dead and not _is_shooting:
			_fengliu_action_scheduler.check_triggers()

		if _fengliu_action_scheduler.any_action_takes_over_physics():
			return

	._physics_process(delta)


# 动作宿主接口：泥潭半径等需要武器阶数
func fengliu_get_action_tier() -> int:
	var weapon_ref = get("_current_weapon_ref")
	if weapon_ref == null:
		return 0

	return int(weapon_ref.tier)


func fengliu_uses_custom_projectile_forms() -> bool:
	return false


func should_shoot() -> bool:
	if _fengliu_action_scheduler != null:
		if _fengliu_action_scheduler.should_block_shoot():
			# 有接管动作时仍按原版条件判断，冷却结束后交给 shoot() 接管
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
		if not _fengliu_prepare_takeover_shot():
			return

		if _fengliu_action_scheduler.should_count_attack():
			_fengliu_action_scheduler.register_normal_attack()

		takeover_action.fengliu_take_over_shoot()
		_fengliu_action_scheduler.finish_takeover(takeover_action)
		return

	if _fengliu_action_scheduler.should_block_shoot():
		return

	if _fengliu_action_scheduler.should_count_attack():
		_fengliu_action_scheduler.register_normal_attack()

	var active_actions = _fengliu_action_scheduler.get_active_actions()
	for action in active_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_before_shoot()

	.shoot()

	for action in active_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_after_shoot()


# 动作接管开火：只准备炮塔朝向，不生成普通炮弹
func _fengliu_prepare_takeover_shot() -> bool:
	if _current_target.size() == 0 or not is_instance_valid(_current_target[0]):
		_is_shooting = false
		_cooldown = _get_next_cooldown()
		return false

	# 动作自身会按 stats.accuracy 加散布，这里保留纯瞄准角
	_next_proj_rotation = (Utils.get_target_position(_current_target[0], global_position) - global_position).angle()
	return true


# 扩展炮弹生成：普通炮弹生成后转给当前激活的动作
func _spawn_projectile(position: Vector2) -> Node:
	var proj = ._spawn_projectile(position)
	if is_instance_valid(proj):
		_fengliu_attach_actions_to_projectile(proj)
	return proj


# 动作自行生成炮弹后由宿主补做动作快照与命中连接
func fengliu_on_action_projectile_shot(projectile) -> void:
	_fengliu_attach_actions_to_projectile(projectile)


func _fengliu_attach_actions_to_projectile(projectile) -> void:
	if projectile == null or not is_instance_valid(projectile) or _fengliu_action_scheduler == null:
		return

	var active_actions = _fengliu_action_scheduler.get_active_actions()
	if active_actions.empty():
		return

	_fengliu_action_scheduler.store_actions_on_projectile(projectile, active_actions)
	for action in active_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_projectile_shot(projectile)

	if projectile.has_signal("hit_something") and not projectile.is_connected("hit_something", self, "_fengliu_on_turret_action_projectile_hit"):
		var _hit_error = projectile.connect("hit_something", self, "_fengliu_on_turret_action_projectile_hit", [projectile])

	var hitbox = projectile.get("_hitbox")
	if hitbox != null and hitbox.has_signal("killed_something"):
		if not hitbox.is_connected("killed_something", self, "on_killed_something"):
			var _kill_error = hitbox.connect("killed_something", self, "on_killed_something", [hitbox])


# 炮弹命中：按发射时快照转发给动作
func _fengliu_on_turret_action_projectile_hit(thing_hit, damage_dealt, projectile) -> void:
	if _fengliu_action_scheduler == null:
		return

	var actions = _fengliu_action_scheduler.get_actions_from_projectile(projectile)
	if actions.empty():
		actions = _fengliu_action_scheduler.get_active_actions()

	for action in actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_projectile_hit(thing_hit, damage_dealt, projectile)



# ---- ranged_action 宿主接口 ----

func fengliu_get_action_stats():
	return stats


func fengliu_get_action_base_projectiles() -> int:
	var weapon_ref = get("_current_weapon_ref")
	if weapon_ref != null and weapon_ref.stats != null and "nb_projectiles" in weapon_ref.stats:
		return int(max(0, int(weapon_ref.stats.nb_projectiles)))
	return 0


func fengliu_get_action_muzzle_position() -> Vector2:
	if _muzzle != null and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return global_position


func fengliu_get_action_shoot_rotation() -> float:
	return _next_proj_rotation


func fengliu_get_action_attack_id() -> int:
	_fengliu_attack_id += 1
	return _fengliu_attack_id


func fengliu_get_action_damage_tracking_key() -> int:
	return _damage_tracking_key_hash


func fengliu_get_action_from_node():
	return self
