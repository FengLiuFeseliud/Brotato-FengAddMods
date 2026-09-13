class_name AutoOpenBox
extends Effect


# ============================================================
# 效果：自动开箱
#   拾取箱子时跳过 UI，自动开箱。
#   运行时 custom_key：fengliu_auto_open_box
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================

func apply(player_index: int) -> void:
	FengLiuUtils.bind_effect(custom_key_hash, player_index, [key_hash, value])
	

func unapply(player_index: int) -> void:
	FengLiuUtils.unbind_effect(custom_key_hash, player_index, [key_hash, value])