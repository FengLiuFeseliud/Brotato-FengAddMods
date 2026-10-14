class_name HoldAttractNearbyConsumables
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


static func get_id() -> String:
	return "fengliu_hold_attract_nearby_consumables"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])