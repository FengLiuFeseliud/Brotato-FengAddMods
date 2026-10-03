class_name ShieldNotRegen
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：护盾不再恢复
#   拥有后，护盾的一切恢复途径（自动回盾、消耗品回盾等）全部失效。
#   判定点见扩展脚本 extensions/entities/units/player/player.gd 的
#   fengliu_shield_regen。
#   运行时 custom_key：fengliu_shield_not_regen
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑
# ============================================================


static func get_id() -> String:
	return "fengliu_shield_not_regen"


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
