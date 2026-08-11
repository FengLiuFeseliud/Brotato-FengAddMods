class_name ApplyItemNotAddEffect
extends Effect


export (bool) var reversal = false
export (bool) var all_stats = false


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, reversal, all_stats])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, reversal, all_stats])