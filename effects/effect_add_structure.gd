class_name AddStucture
extends Effect


export (int) var gain_value = 0 # 倍率
export (Resource) var stucture_effect
var _init_stats_args_structure :=  WeaponServiceInitStatsArgs.new()


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, gain_value, stucture_effect])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, gain_value, stucture_effect])


func get_args(player_index: int) -> Array:
    var args = .get_args(player_index)
    var scaling_stats_names = WeaponService.get_scaling_stats_icon_text(stucture_effect.stats.scaling_stats)
    var init_stats  = WeaponService.init_structure_stats(stucture_effect.stats, player_index, _init_stats_args_structure)

    return [
        args[0], 
        args[1], 
        Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0),
        tr(stucture_effect.text_key.to_upper()),
        str(init_stats.damage),
        scaling_stats_names
    ]