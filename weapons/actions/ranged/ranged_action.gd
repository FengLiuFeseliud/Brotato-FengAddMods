extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/action.gd"


# ============================================================
# 远程动作基类
#   在通用动作基类上增加远程类型标记，供远程武器类与远程动作使用。
#   远程专属的「接管一次开火」也在这里声明：武器开火前询问是否接管，
#   接管时由动作自行生成子弹，武器不再执行普通攻击。
# ============================================================


func fengliu_is_ranged_action() -> bool:
	return true


# 是否由本动作接管本次开火；返回 true 时不执行武器普通攻击
func fengliu_should_take_over_shoot() -> bool:
	return false


# 接管开火时由武器调用一次；动作自行生成子弹
func fengliu_take_over_shoot() -> void:
	pass


# 投射物生成钩子：武器生成子弹后调用；默认不处理
func fengliu_on_projectile_shot(_projectile) -> void:
	pass


# 投射物命中钩子：武器/炮塔在子弹命中时调用；默认不处理
func fengliu_on_projectile_hit(_thing_hit, _damage_dealt, _projectile) -> void:
	pass


# ---- 动作宿主（武器 / 炮塔）通用访问 ----

func fengliu_get_host_effects() -> Array:
	if _fengliu_weapon == null:
		return []

	var value = _fengliu_weapon.get("effects")
	return value if value is Array else []


func fengliu_get_host_player_index() -> int:
	if _fengliu_weapon == null:
		return -1

	var value = _fengliu_weapon.get("player_index")
	return int(value) if value != null else -1


func fengliu_get_host_tier() -> int:
	if _fengliu_weapon == null:
		return 0

	if _fengliu_weapon.has_method("fengliu_get_action_tier"):
		return int(_fengliu_weapon.fengliu_get_action_tier())

	var value = _fengliu_weapon.get("tier")
	return int(value) if value != null else 0


# 宿主是否自行决定投射物形态：武器 custom shooting behavior 为 true，炮塔为 false
func fengliu_host_uses_custom_projectile_form() -> bool:
	if _fengliu_weapon == null:
		return false

	if _fengliu_weapon.has_method("fengliu_uses_custom_projectile_forms"):
		return bool(_fengliu_weapon.fengliu_uses_custom_projectile_forms())

	return false


# ---- 动作宿主数据访问：武器 / 炮塔 / 蓝鲸统一入口 ----

func fengliu_get_host_action_stats():
	if _fengliu_weapon == null:
		return null

	if _fengliu_weapon.has_method("fengliu_get_action_stats"):
		return _fengliu_weapon.fengliu_get_action_stats()

	var value = _fengliu_weapon.get("current_stats")
	if value == null:
		value = _fengliu_weapon.get("stats")
	return value


func fengliu_get_host_base_projectiles() -> int:
	if _fengliu_weapon == null:
		return 0

	if _fengliu_weapon.has_method("fengliu_get_action_base_projectiles"):
		return int(max(0, int(_fengliu_weapon.fengliu_get_action_base_projectiles())))

	var value = _fengliu_weapon.get("stats")
	if value != null and "nb_projectiles" in value:
		return int(max(0, int(value.nb_projectiles)))
	return 0


func fengliu_get_host_muzzle_position() -> Vector2:
	if _fengliu_weapon == null:
		return Vector2.ZERO

	if _fengliu_weapon.has_method("fengliu_get_action_muzzle_position"):
		return _fengliu_weapon.fengliu_get_action_muzzle_position()

	var muzzle = _fengliu_weapon.get("muzzle")
	if muzzle == null:
		muzzle = _fengliu_weapon.get("_muzzle")
	if muzzle != null and is_instance_valid(muzzle) and "global_position" in muzzle:
		return muzzle.global_position

	if "global_position" in _fengliu_weapon:
		return _fengliu_weapon.global_position
	return Vector2.ZERO


func fengliu_get_host_shoot_rotation() -> float:
	if _fengliu_weapon == null:
		return 0.0

	if _fengliu_weapon.has_method("fengliu_get_action_shoot_rotation"):
		return float(_fengliu_weapon.fengliu_get_action_shoot_rotation())

	var rotation_value = _fengliu_weapon.get("rotation")
	return float(rotation_value) if rotation_value != null else 0.0


func fengliu_get_host_attack_id() -> int:
	if _fengliu_weapon == null:
		return -1

	if _fengliu_weapon.has_method("fengliu_get_action_attack_id"):
		return int(_fengliu_weapon.fengliu_get_action_attack_id())

	var behavior = _fengliu_weapon.get("_shooting_behavior")
	if behavior != null and is_instance_valid(behavior) and behavior.has_method("_get_next_attack_id"):
		return int(behavior._get_next_attack_id())

	return -1


func fengliu_get_host_damage_tracking_key() -> int:
	if _fengliu_weapon == null:
		return Keys.empty_hash

	if _fengliu_weapon.has_method("fengliu_get_action_damage_tracking_key"):
		return int(_fengliu_weapon.fengliu_get_action_damage_tracking_key())

	var value = _fengliu_weapon.get("damage_tracking_key_hash")
	if value == null:
		value = _fengliu_weapon.get("_damage_tracking_key_hash")
	return int(value) if value != null else Keys.empty_hash


# 实际生成投射物时使用的来源节点；蓝鲸动作宿主是 Reference，需要返回蓝鲸本体
func fengliu_get_host_from_node():
	if _fengliu_weapon == null:
		return null

	if _fengliu_weapon.has_method("fengliu_get_action_from_node"):
		return _fengliu_weapon.fengliu_get_action_from_node()

	return _fengliu_weapon


# 动作自行生成投射物后，通知宿主补做命中/快照桥接
func fengliu_notify_host_projectile_shot(projectile) -> void:
	if _fengliu_weapon == null or not is_instance_valid(projectile):
		return

	if _fengliu_weapon.has_method("fengliu_on_action_projectile_shot"):
		_fengliu_weapon.fengliu_on_action_projectile_shot(projectile)
		return

	if _fengliu_weapon.has_method("on_projectile_shot"):
		_fengliu_weapon.on_projectile_shot(projectile)

