extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_exploding_effect.gd"


# ============================================================
# 效果：爆炸并留下水洼
#   触发方式与「爆炸」一致，区别是爆炸落点会留下一片水洼（独立 water_zone 场景）：
#   水洼让圈内敌人潮湿、让玩家打滑，本身不造成任何直接伤害、也不会点燃。
#   运行时 custom_key：无（沿用爆炸类效果的 key，如 effect_explode_custom）
# ------------------------------------------------------------
# 效果值：
#   chance              爆炸触发概率
#   scale               爆炸范围倍数
#   puddle_scale        水洼半径 = 爆炸实际半径 × 该倍率
#   puddle_duration     水洼持续时间（秒）
#   wet_duration        潮湿持续时间（秒）
#   wet_tick_interval   水洼刷新潮湿的间隔（秒）
# ============================================================

export (float) var puddle_scale = 1.0
export (float) var puddle_duration = 4.0
export (float) var wet_duration = 2.0
export (float) var wet_tick_interval = 0.5


static func get_id() -> String:
	return "fengliu_water_exploding"


func get_args(_player_index: int) -> Array:
	return ["%s%%" % str(round(chance * 100.0)), str(puddle_duration), str(wet_duration)]
