class_name WpaponKilledAddTempStat
extends NullEffect


# ============================================================
# 效果：武器击杀增加临时属性
#   用该武器击杀敌人时，有概率临时增加指定属性，直至敌袭结束。
#   触发概率可吃倍率属性。
#   运行时 custom_key：fengliu_wpapon_killed_add_temp_stat
# ------------------------------------------------------------
# 效果值：
#   key          临时增加的属性
#   value        基础触发概率（%）
#   gain_stat    概率倍率属性
#   gain_value   概率倍率（每 gain_value/100 点该属性 +1% 概率）
#   stat_nb      临时增加的数值
# ============================================================

export (String) var gain_stat = "" # 概率倍率属性
export (int) var gain_value = 0 # 概率倍率：每 gain_value/100 点该属性 +1% 概率
export (int) var stat_nb = 1 # 临时增加的数值
var gain_stat_hash = 0 # 概率倍率属性哈希


func _generate_hashes() -> void:
	._generate_hashes()
	gain_stat_hash = Keys.generate_hash(gain_stat)


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{3} 占位符：
    #   [0] = 动态触发概率百分比（绿色）
    #   [1] = 概率倍率属性图标文本
    #   [2] = 临时增加的数值（绿色 +N）
    #   [3] = 临时增加的属性名（基类 args[1]）
    var dynamic_chance = value + (Utils.get_stat(gain_stat_hash, player_index) * (gain_value / 100.0))
    if dynamic_chance > 100:
        dynamic_chance = 100

    return [
        "[color=lime]%s%%[/color]" % dynamic_chance, 
        Utils.get_scaling_stat_icon_text(gain_stat_hash, gain_value / 100.0),
        "[color=lime]+%s[/color]" % str(stat_nb),
        .get_args(player_index)[1]
    ]  