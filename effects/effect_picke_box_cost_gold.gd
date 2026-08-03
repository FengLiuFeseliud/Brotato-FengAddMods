class_name PickeBoxCostGold
extends Effect


export (int) var gain_value = 100 # 倍率
export (int) var random_get_stat = 0 # 随机获取属性


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, gain_value, random_get_stat])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, gain_value, random_get_stat])


func get_args(player_index: int) -> Array:
	return [
		str(value + int(RunData.get_player_gold(player_index) * (gain_value / 100.0))), 
		"[color=lime]+%s%%[/color]" % str(gain_value),
		"[color=lime]%s[/color]" % str(random_get_stat)
	]
