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


func apply(player_index: int) -> void:
	# 计数 +1；槽位异常（非整数）按 0 兜底，避免读到空数组
	var effects = RunData.get_player_effects(player_index)
	var count = effects.get(custom_key_hash, 0)
	effects[custom_key_hash] = (count if count is int else 0) + 1


func unapply(player_index: int) -> void:
	# 计数 -1，下限 0（多份道具/读档后仍与原版 apply/unapply 配套）
	var effects = RunData.get_player_effects(player_index)
	var count = effects.get(custom_key_hash, 0)
	effects[custom_key_hash] = max(0, (count if count is int else 0) - 1)
