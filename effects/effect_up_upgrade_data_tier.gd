class_name UpUpgradeDataTier
extends Effect


export (int) var gain_value = 0 # 倍率：每 gain_value/100 点 key 属性 +1% 概率


static func get_dynamic_chance(init_chance: int, add_chance: int = 100, stat_count: int = 0) -> int:
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	if dynamic_chance > 100:
		return 100
		
	return dynamic_chance


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, gain_value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, gain_value])


func get_args(player_index: int) -> Array:
    if key_hash == Keys.empty_hash:
        return [ "[color=lime]%s%%[/color]" % int(gain_value / 100.0) ]
        
    var args = .get_args(player_index)
    return [
        "[color=lime]%s%%[/color]" % get_dynamic_chance(value, gain_value, int(Utils.get_stat(key_hash, player_index))),
        args[1],
        Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)
    ]