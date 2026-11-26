class_name WeaponWetEffect
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_null_effect.gd"


# ============================================================
# 效果：武器命中潮湿（无概率）
#   用该武器命中敌人时，必定使其潮湿：持续 wet_duration 秒，期间显示雨滴粒子。
#   重复命中只刷新时长（取剩余与新时长的较大值）。
#   运行时 custom_key：fengliu_weapon_wet
# ------------------------------------------------------------
# 效果值：
#   wet_duration  潮湿持续时间（秒）
# ============================================================

export (float) var wet_duration = 2.0


static func get_id() -> String:
	return "fengliu_weapon_wet"


func get_args(_player_index: int) -> Array:
	# 整秒时输出 "2" 而不是 "2.0"，让 tooltip 读起来自然
	var text: String = str(int(wet_duration)) if is_equal_approx(wet_duration, round(wet_duration)) else str(wet_duration)
	return [text]
