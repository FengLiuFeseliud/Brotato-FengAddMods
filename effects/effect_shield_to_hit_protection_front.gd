class_name ShieldToHitProtectionFront
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：护盾优先于防护
#   拥有后，护盾插到「抵消伤害的机会」前面承伤：
#   玩家还有抵消伤害的机会时，这一击也先由护盾吃下。
#   运行时 custom_key：fengliu_shield_to_hit_protection_front
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑；
# ============================================================


static func get_id() -> String:
	return "fengliu_shield_to_hit_protection_front"


func fengliu_get_effect_init_value():
	return 0


func apply(player_index: int) -> void:
	# 计数 +1
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = effects.get(custom_key_hash, 0) + 1


func unapply(player_index: int) -> void:
	# 计数 -1，下限 0
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = max(0, effects.get(custom_key_hash, 0) - 1)
