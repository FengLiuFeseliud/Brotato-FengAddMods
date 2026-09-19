class_name WaveEndNotPickConsumable
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：波次结束不自动拾取消耗品
#   波次结束时阻止消耗品被自动拾取。
#   运行时 custom_key：fengliu_wave_end_not_pick_consumable
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================


static func get_id() -> String:
	return "fengliu_wave_end_not_pick_consumable"

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])
