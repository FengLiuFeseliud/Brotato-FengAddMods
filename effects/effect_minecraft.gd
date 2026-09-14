class_name Minecreft
extends Effect


# ============================================================
# 效果：我的世界模式
#   开启 MC 模式：向关卡注入矿石怪群组，中立怪死亡掉落木棍/橡木。
#   运行时 custom_key：fengliu_minecraft
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])
