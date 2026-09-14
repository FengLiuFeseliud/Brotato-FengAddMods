class_name WaveElitesSpawn
extends Effect


# ============================================================
# 效果：每波生成精英
#   每波开始时随机生成一个精英怪。
#   运行时 custom_key：fengliu_wave_elites_spawn
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])