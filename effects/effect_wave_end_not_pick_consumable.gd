class_name WaveEndNotPickConsumable
extends Effect


# ============================================================
# 效果：波次结束不自动拾取消耗品
#   波次结束时阻止消耗品被自动拾取。
#   运行时 custom_key：fengliu_wave_end_not_pick_consumable
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================

func apply(player_index: int) -> void:
	FengLiuUtils.bind_effect(custom_key_hash, player_index, [key_hash, value])
	

func unapply(player_index: int) -> void:
	FengLiuUtils.unbind_effect(custom_key_hash, player_index, [key_hash, value])
