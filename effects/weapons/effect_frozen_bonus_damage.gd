extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_null_effect.gd"


# ============================================================
# 效果：击中冰冻目标时伤害倍率
#   用该武器命中「已处于冰冻状态」的敌人时，最终伤害 × multiplier。
#   本次命中才造成冰冻的不算（先结算伤害，再尝试冰冻）。
#   运行时 custom_key：fengliu_frozen_bonus_damage
# ------------------------------------------------------------
# 效果值：
#   multiplier  对冰冻目标的伤害倍率（1.0 = 无加成）
# ============================================================

export (float) var multiplier = 2.0


static func get_id() -> String:
	return "fengliu_frozen_bonus_damage"


func get_args(_player_index: int) -> Array:
	# 整倍率显示为 "2"，否则保留小数
	var text: String = str(int(multiplier)) if is_equal_approx(multiplier, round(multiplier)) else str(multiplier)
	return [text]
