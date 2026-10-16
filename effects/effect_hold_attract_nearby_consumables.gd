class_name HoldAttractNearbyConsumables
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：随时吸取消耗品
#   不管距离多远、是否在拾取范围内，都会持续
#   吸取场上的消耗品。
#   运行时 custom_key：fengliu_hold_attract_nearby_consumables
# ------------------------------------------------------------
# 效果值：
#   key      未使用（留空）
#   value    未使用（留空，判定只看实例是否存在）
# ============================================================


static func get_id() -> String:
	return "fengliu_hold_attract_nearby_consumables"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])