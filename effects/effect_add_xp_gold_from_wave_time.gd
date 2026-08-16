class_name AddXpGoldFromWaveTime
extends Effect


export (float) var gain_value = 0.0


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, gain_value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, gain_value])


func get_args(player_index: int) -> Array:
    var add_gold = 0
    if key_hash != Keys.stat_levels_hash:
        add_gold = value + RunData.get_stat(key_hash, player_index) * gain_value
    else:
        add_gold = value + RunData.get_player_level(player_index) * gain_value

    return [
        str(add_gold),
        Utils.get_scaling_stat_icon_text(key_hash, gain_value)
    ]