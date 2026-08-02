class_name GoldLowSetHpShopEffect
extends Effect


export (int) var gold


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, gold])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, gold])


func get_args(_player_index: int) -> Array:
    return ["[color=lime]%s%%[/color]" % gold]
