class_name AddStatFromWaveIntensity
extends Effect


export (int) var boss_wave_add_value = 0
export (int) var value_cap = 0


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, boss_wave_add_value, value_cap, "stat_" in key])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, boss_wave_add_value, value_cap, "stat_" in key])


func get_args(player_index: int) -> Array:
	var args = .get_args(player_index)
	return [
		args[1],
		args[0],
		str(boss_wave_add_value),
		str(value_cap)
	]