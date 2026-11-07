class_name WeaponBurnDamageEffect
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：总和武器燃烧
#   把「玩家所有武器燃烧效果的伤害总和」按比例作为敌人身上的
#   每一跳「燃烧」伤害。
#   运行时 custom_key：fengliu_weapon_burn_damage
# ------------------------------------------------------------
# 效果值：
#   value   并入比例（%，100 = 全额并入）
# ============================================================


static func get_id() -> String:
	return "fengliu_weapon_burn_damage"


# 数值累加 / 消费端遍历，异变复制有效
func fengliu_can_be_copied_by_mutation() -> bool:
	return true


func apply(player_index: int) -> void :
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = effects.get(custom_key_hash, 0) + value


func unapply(player_index: int) -> void :
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = max(0, effects.get(custom_key_hash, 0) - value)


# 槽位存的是单个数值（不是列表）
func fengliu_get_effect_init_value():
	return 0


func get_args(_player_index: int) -> Array:
	# 描述只需并入比例
	return [str(value)]