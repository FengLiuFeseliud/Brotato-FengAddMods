class_name TurretCopy
extends Effect


# ============================================================
# 效果：炮塔复制
#   炮塔击杀目标时，按概率复制一座炮塔。
#   运行时 custom_key：fengliu_turret_copy
# ------------------------------------------------------------
# 效果值：
#   key        倍率属性（复制概率所吃的属性）
#   value      基础复制概率（%）
#   gain_value 概率倍率（每 gain_value/100 点该属性 +1% 概率）
# ============================================================

export (int) var gain_value = 0 # 倍率：每 gain_value/100 点 key 属性 +1% 概率


static func get_dynamic_chance(init_chance: int, add_chance: int = 100, stat_count: int = 0) -> int:
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	if dynamic_chance > 100:
		return 100
		
	return dynamic_chance


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, gain_value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, gain_value])


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{2} 占位符：
    #   [0] = 动态复制概率百分比（绿色）
    #   [1] = 属性名（基类 args[1]）
    #   [2] = 倍率属性图标文本
    var args = .get_args(player_index)
    return [
        "[color=lime]%s%%[/color]" % get_dynamic_chance(value, gain_value, int(Utils.get_stat(key_hash, player_index))),
        args[1],
        Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)
    ]