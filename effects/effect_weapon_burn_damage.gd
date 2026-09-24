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


func apply(player_index: int) -> void:
	# 效果槽存 [并入比例]
	RunData.get_player_effect(custom_key_hash, player_index).push_back([value])


func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([value])


func get_args(_player_index: int) -> Array:
	# 描述只需并入比例
	return ["[color=lime]%s%%[/color]" % value]
