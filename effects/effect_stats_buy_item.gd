class_name StatsBuyItem
extends Effect


# ============================================================
# 效果：用属性购买道具时获得属性
#   用属性支付、金币不足购买道具时，获得指定属性（回馈）。
#   运行时 custom_key：fengliu_stats_buy_item
# ------------------------------------------------------------
# 效果值：
#   key    获得的属性
#   value  获得的数值
# ============================================================

func apply(player_index: int) -> void:
	FengLiuUtils.bind_effect(custom_key_hash, player_index, [key_hash, value])
	

func unapply(player_index: int) -> void:
	FengLiuUtils.unbind_effect(custom_key_hash, player_index, [key_hash, value])