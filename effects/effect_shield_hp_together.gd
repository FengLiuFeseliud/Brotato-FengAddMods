class_name ShieldHpTogether
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：护盾与生命一起承伤
#   受击时不再由护盾单独吃下，而是护盾与生命同时分担该次伤害。
#   运行时 custom_key：fengliu_shield_hp_together
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑；
# ============================================================


static func get_id() -> String:
	return "fengliu_shield_hp_together"


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
