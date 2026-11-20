extends "res://entities/structures/turret/builder/builder_turret.gd"


var _fengliu_turret_actions = []


# 扩展设置炮塔数据：base 内部先写 _current_weapon_ref，再调用父级 set_data
func set_data(data: Resource) -> void :
	.set_data(data)
	fengliu_sync_turret_actions()


# ============================================================
# 通用动作桥接：读取被复制武器场景的 actions，不识别具体武器
#   仅桥接常驻动作（trigger_count <= 0）；触发型动作需要攻击计数调度。
# ============================================================

func fengliu_sync_turret_actions() -> void:
	_fengliu_turret_actions.clear()

	var weapon_ref = get("_current_weapon_ref")
	if weapon_ref == null or not weapon_ref.has_method("fengliu_get_actions"):
		return

	for action_resource in weapon_ref.fengliu_get_actions():
		if action_resource == null or not action_resource.has_method("fengliu_is_ranged_action"):
			continue

		var action = action_resource.duplicate()
		if action == null:
			continue

		action.fengliu_setup(self)

		# 触发型动作需要攻击次数与冷却调度，炮塔侧暂不启用
		if action.fengliu_get_trigger_count() > 0:
			continue

		action.fengliu_start()
		_fengliu_turret_actions.push_back(action)


# 动作宿主接口：泥潭半径等需要武器阶数
func fengliu_get_action_tier() -> int:
	var weapon_ref = get("_current_weapon_ref")
	if weapon_ref == null:
		return 0

	return int(weapon_ref.tier)


# 扩展炮弹生成：把投射物事件转给已桥接的动作
func _spawn_projectile(position: Vector2) -> Node:
	var proj = ._spawn_projectile(position)
	if not is_instance_valid(proj) or _fengliu_turret_actions.empty():
		return proj

	for action in _fengliu_turret_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_projectile_shot(proj)

	if proj.has_signal("hit_something") and not proj.is_connected("hit_something", self, "_fengliu_on_turret_action_projectile_hit"):
		var _error = proj.connect("hit_something", self, "_fengliu_on_turret_action_projectile_hit", [proj])

	return proj


# 炮弹命中：转发给已桥接的动作
func _fengliu_on_turret_action_projectile_hit(thing_hit, damage_dealt, projectile) -> void:
	for action in _fengliu_turret_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_projectile_hit(thing_hit, damage_dealt, projectile)
