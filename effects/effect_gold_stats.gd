class_name GoldStats
extends Effect


# ============================================================
# 效果：捡材料获得属性
#   捡起材料/金币时，有概率永久获得指定属性。
#   运行时 custom_key：fengliu_gold_stats
# ------------------------------------------------------------
# 效果值：
#   key      获得的属性（非主属性则累加到增益池）
#   value    触发概率（%）
#   stat_nb  获得的数值
# ============================================================

export (int) var stat_nb = 0 # 获得的数值


func apply(player_index: int) -> void:
	FengLiuUtils.bind_effect(custom_key_hash, player_index, [key_hash, value, stat_nb])


func unapply(player_index: int) -> void:
	FengLiuUtils.unbind_effect(custom_key_hash, player_index, [key_hash, value, stat_nb])


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{2} 占位符：
    #   [0] = 触发概率百分比（基类 args[0]，绿色）
    #   [1] = 获得的数值 +N（绿色）
    #   [2] = 获得的属性名（基类 args[1]）
    var args = .get_args(player_index)

    return [
        FengLiuUtils.text_percent(args[0]),
        FengLiuUtils.text_value_plus(stat_nb) if stat_nb > 0 else FengLiuUtils.text_value(stat_nb),
        args[1]
    ]