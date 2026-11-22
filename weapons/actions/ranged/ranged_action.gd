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
