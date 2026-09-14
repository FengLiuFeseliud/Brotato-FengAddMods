class_name AddXpGoldFromWaveTime
extends Effect


# ============================================================
# 效果：波次结束按剩余时间加经验/金币
#   波次结束（清理房间）时，按波次计时器剩余时间加金币与经验。
#   运行时 custom_key：fengliu_add_xp_gold_from_wave_time
# ------------------------------------------------------------
# 效果值：
#   key        用于加算的属性（levels 则按玩家等级加算）
#   value      基础每秒增加值
#   gain_value 倍率（额外 = 属性 × gain_value）
# ============================================================

export (float) var gain_value = 0.0 # 倍率：额外 = 属性(或等级) × gain_value


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, gain_value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, gain_value])


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0} {1} 占位符：
    #   [0] = 最终每秒增加的经验/金币值
    #   [1] = 倍率属性图标文本
    var add_gold = 0
    if key_hash != Keys.stat_levels_hash:
        add_gold = value + RunData.get_stat(key_hash, player_index) * gain_value
    else:
        add_gold = value + RunData.get_player_level(player_index) * gain_value

    return [
        str(add_gold),
        Utils.get_scaling_stat_icon_text(key_hash, gain_value)
    ]