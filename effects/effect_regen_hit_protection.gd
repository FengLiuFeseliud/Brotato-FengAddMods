class_name RegenHitProtection
extends Effect


# ============================================================
# 效果：恢复护盾（免伤层）
#   定时恢复护盾（hit protection），恢复概率可吃倍率属性。
#   运行时 custom_key：fengliu_regen_hit_protection
# ------------------------------------------------------------
# 效果值：
#   key        倍率属性（恢复概率所吃的属性）
#   value      基础恢复概率（%）
#   wait_time  恢复间隔时间
#   gain_value 概率倍率（每 gain_value/100 点该属性 +1% 概率）
# ============================================================

export (int) var wait_time = 1 # 恢复间隔时间
export (int) var gain_value = 100 # 倍率：每 gain_value/100 点 key 属性 +1% 概率


static func get_dynamic_chance(init_chance: int, add_chance: int = 100, stat_count: int = 0) -> int:
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	if dynamic_chance > 100:
		return 100
		
	return dynamic_chance


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, wait_time, gain_value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, wait_time, gain_value])


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{2} 占位符：
	#   [0] = 动态恢复概率百分比（绿色）
	#   [1] = 恢复间隔时间 (wait_time)
	#   [2] = 倍率属性图标文本
	return [
        "[color=lime]%s%%[/color]" % get_dynamic_chance(value, gain_value, int(Utils.get_stat(key_hash, player_index))),
        str(wait_time),
		Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)
	]
