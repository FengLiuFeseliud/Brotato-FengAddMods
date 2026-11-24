class_name GainRandomPrimaryStatsOnObtain
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：获得属性翻倍 / 反转强化
#   持有该效果时，fengliu_random_primary_stats_on_obtain 每次获得的属性：
#     先按 value% 概率整批翻倍；未命中再按 debuff_chance% 概率整批变为扣除，
#     并使下一波以 1 点生命开始。
#   运行时 custom_key：fengliu_gain_random_primary_stats_on_obtain
# ------------------------------------------------------------
# 效果值：
#   value          翻倍概率（%）
#   debuff_chance  反转强化概率（%）
# ============================================================

export (int) var debuff_chance = 0


static func get_id() -> String:
	return "fengliu_gain_random_primary_stats_on_obtain"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back([value, debuff_chance])


func unapply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).erase([value, debuff_chance])


func fengliu_get_effect_init_value():
	return []


func get_args(_player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{1} 占位符：
	#   [0] = 翻倍概率（百分号由 text.gd 的 keys_needing_percent 补）
	#   [1] = 反转强化概率
	return [str(value), str(debuff_chance)]
