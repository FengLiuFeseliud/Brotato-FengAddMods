class_name PickBoxCostGold
extends Effect


export (float) var wave_inflation_rate
export (int) var random_get_stat = 0 # 随机获取属性


func get_box_cost() -> int:
    return int(value * (1.0 + (max(1, RunData.current_wave) - 1) * wave_inflation_rate))


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, wave_inflation_rate, random_get_stat])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, wave_inflation_rate, random_get_stat])


func get_args(_player_index: int) -> Array:
	return [
		str(get_box_cost()), 
		"[color=lime]%s[/color]" % str(random_get_stat)
	]
