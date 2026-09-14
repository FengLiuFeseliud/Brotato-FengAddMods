class_name BoxStats
extends Effect


# ============================================================
# 效果：开箱获得属性
#   开箱子时获得指定属性。
#   运行时 custom_key：fengliu_box_stats
# ------------------------------------------------------------
# 效果值：
#   key    获得的属性
#   value  获得的数值
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0} {1} 占位符：
    #   [0] = 获得的数值 +N（绿色）
    #   [1] = 获得的属性名（大写翻译）
    var args = .get_args(player_index)    
    return ["[color=lime]+%s[/color]" % args[0], args[1]]