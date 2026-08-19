class_name KilledAllBossWaveEnd
extends Effect


# ============================================================
# 效果：击杀全部 Boss 结束波次
#   击杀最后一个 Boss/精英时直接结束当前波次。
#   运行时 custom_key：fengliu_killed_all_boss_wave_end
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])