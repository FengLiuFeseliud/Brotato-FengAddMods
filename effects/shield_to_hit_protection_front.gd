class_name ShieldToHitProtectionFront
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：护盾优先于防护
#   拥有后，护盾插到「抵消伤害的机会」前面承伤：
#   玩家还有抵消伤害的机会时，这一击也先由护盾吃下。
#   判定点见扩展脚本 extensions/entities/units/player/player.gd 的
#   fengliu_can_shield_take_damage。
#   运行时 custom_key：fengliu_shield_to_hit_protection_front
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑；
#   槽位存整数计数，供 RunData.get_player_effect_bool 判定（> 0 即生效）。
# ============================================================


static func get_id() -> String:
	return "fengliu_shield_to_hit_protection_front"


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
