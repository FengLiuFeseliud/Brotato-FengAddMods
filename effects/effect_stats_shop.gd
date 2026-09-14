class_name StatsShop
extends Effect


# ============================================================
# 效果：用属性替代金币购买
#   用某属性替代金币作为货币购买商店道具。
#   运行时 custom_key：fengliu_stats_stop
# ------------------------------------------------------------
# 效果值：
#   key               作为货币的属性
#   value             汇率（货币值 = 该属性 × value）
#   alternative_coins 是否仍允许金币购买（true=金币足够时仍用金币，属性仅作替代）
# ============================================================

export (bool) var alternative_coins = false # true=金币足够时仍用金币，属性仅作替代


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, alternative_coins])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, alternative_coins])
