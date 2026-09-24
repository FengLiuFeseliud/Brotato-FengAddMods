class_name BurningSlowEffect
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：燃烧伤害减速
#   敌人每受到一跳「燃烧」伤害就被减速，减速值可吃倍率属性。
#   运行时 custom_key：fengliu_burning_slow
# ------------------------------------------------------------
# 效果值：
#   key        减速倍率属性（提升减速值所吃的属性）
#   value      基础减速值
#   gain_value 减速倍率（减速值 += 该属性 × gain_value/100）
# ============================================================

export (int) var gain_value = 0


static func get_id() -> String:
	return "fengliu_burning_slow"


func apply(player_index: int) -> void:
	# 效果槽存 [倍率属性, 基础减速值, 减速倍率]
	RunData.get_player_effect(custom_key_hash, player_index).push_back([key_hash, value, gain_value])


func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, gain_value])


func get_args(player_index: int) -> Array:
	# 减速值 = 基础值 + 倍率属性 × gain_value/100
	var slow_value = value + int(Utils.get_stat(key_hash, player_index) * (gain_value / 100.0))
	return [
		"[color=lime]%s[/color]" % slow_value,
		Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)
	]
