class_name NoKillEnemy
extends Effect


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key])


func get_args(player_index: int) -> Array:
	var args = .get_args(player_index)
	return [
		"[color=lime]%s[/color]" % args[1]
	]