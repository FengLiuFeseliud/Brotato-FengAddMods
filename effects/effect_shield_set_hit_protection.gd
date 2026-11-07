class_name ShieldSetHitProtection
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：护盾当作抵消伤害的机会
#   拥有后，护盾改用「每击固定消耗」结算：每受一次击固定消耗
#   <value> 点护盾即可抵消该次伤害；护盾不足以支付时才被打穿。
#   判定点见扩展脚本 extensions/entities/units/player/player.gd 的
#   take_damage「盾优先」分支。
#   运行时 custom_key：fengliu_shield_set_hit_protection
# ------------------------------------------------------------
# 效果值：
#   value   每受击固定消耗的护盾点数（护盾够支付时该次伤害被完全抵消）
# ============================================================


static func get_id() -> String:
	return "fengliu_shield_set_hit_protection"


# 数值累加 / 消费端遍历，异变复制有效
func fengliu_can_be_copied_by_mutation() -> bool:
	return true


func fengliu_get_effect_init_value():
	return 0


func apply(player_index: int) -> void:
	# 累加 value
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = effects.get(custom_key_hash, 0) + value


func unapply(player_index: int) -> void:
	# 扣除 value，下限 0
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = max(0, effects.get(custom_key_hash, 0) - value)