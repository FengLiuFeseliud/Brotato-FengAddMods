class_name ApplyItemNotAddAllDebuff
extends Effect


export (bool) var from_box = false


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([value, from_box])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([value, from_box])


func get_args(player_index: int) -> Array:
	var args = .get_args(player_index)
	return [
		"[color=lime]%s%%[/color]" % args[0]
	]