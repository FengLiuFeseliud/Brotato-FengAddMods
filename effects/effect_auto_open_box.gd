class_name AutoOpenBox
extends ModEffect


# ============================================================
# 效果：自动开箱
#   拾取箱子时跳过 UI，自动开箱。
#   运行时 custom_key：fengliu_auto_open_box
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================


static func get_id() -> String:
	return "fengliu_auto_open_box"

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])
