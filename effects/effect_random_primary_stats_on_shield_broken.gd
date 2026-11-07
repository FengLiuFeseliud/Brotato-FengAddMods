class_name RandomPrimaryStatsOnShieldBroken
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：破盾获得随机主要属性
#   护盾被打破时随机获得 <value> 点主要属性（每点独立随机一项）。
#   判定点见扩展脚本 extensions/entities/units/player/player.gd 的
#   fengliu_on_shield_broken。
#   运行时 custom_key：fengliu_random_primary_stats_on_shield_broken
# ------------------------------------------------------------
# 效果值：
#   value   破盾时随机主要属性的点数
# ============================================================


static func get_id() -> String:
	return "fengliu_random_primary_stats_on_shield_broken"


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
	# 返回数组按顺序填充描述文本占位符：
	#   [0] = 破盾时随机主要属性点数（绿色）
	return ["[color=lime]%s[/color]" % value]