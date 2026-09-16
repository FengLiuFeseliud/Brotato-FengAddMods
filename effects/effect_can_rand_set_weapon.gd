class_name CanRandSetWeapon
extends Effect


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash])


func get_args(_player_index: int) -> Array:
	return [ tr(key.to_upper().replace("SET", "WEAPON_CLASS")) ]