class_name ResetItemStat
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


export (String) var to_stat = ""
var to_stat_hash = Keys.empty_hash


static func get_id() -> String:
	return "fengliu_reset_item_stat"


func _generate_hashes() -> void:
	._generate_hashes()
	to_stat_hash = Keys.generate_hash(to_stat)


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, to_stat_hash])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, to_stat_hash])


func get_args(_player_index: int) -> Array:
    return [
		"[color=lime]%s[/color]" % tr(key.to_upper()), 
		"[color=lime]%s[/color]" % tr(to_stat.to_upper())
	]