class_name StatHitProtection
extends Effect


# ============================================================
# 效果：属性提升护盾
#   根据某属性值提升护盾（hit protection）上限。
#   运行时 custom_key：fengliu_stat_hit_protection
# ------------------------------------------------------------
# 效果值：
#   key    用于计算护盾的属性
#   value  除数（护盾 = 该属性 / value 取整）
# ============================================================

func apply(player_index: int) -> void:
	FengLiuUtils.bind_effect(custom_key_hash, player_index, [key_hash, value])
	

func unapply(player_index: int) -> void:
	FengLiuUtils.unbind_effect(custom_key_hash, player_index, [key_hash, value])


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{2} 占位符：
    #   [0] = 除数 (value)
    #   [1] = 属性名（基类 args[1]）
    #   [2] = 当前护盾值（属性/value，绿色）
    var args = .get_args(player_index)
    return [
        args[0],
        args[1],
        FengLiuUtils.text_value_plus(int(Utils.get_stat(key_hash, player_index) / value))
    ]