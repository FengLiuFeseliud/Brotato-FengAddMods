class_name TempStatsOnHitProtection
extends Effect


# ============================================================
# 效果：受击获得临时属性
#   受到伤害时（护盾恢复机制触发时）获得临时属性。
#   运行时 custom_key：fengliu_temp_stats_on_hit_protection
# ------------------------------------------------------------
# 效果值：
#   key    获得的临时属性
#   value  获得的数值
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])