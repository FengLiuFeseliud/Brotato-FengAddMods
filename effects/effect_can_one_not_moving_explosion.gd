class_name CanOneNotMovingExplosion
extends Effect


# ============================================================
# 效果：允许原地自爆一次
#   清理房间（波次结束判定）时若仍有 Boss/精英存活，
#   允许对自己造成最大生命值伤害（自爆），以阻止波次强制结束。
#   运行时 custom_key：fengliu_can_one_not_moving_explosion
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])