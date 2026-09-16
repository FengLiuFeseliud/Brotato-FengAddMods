class_name ExtraAliens
extends Effect


export (Resource) var aliens_group
export (int) var gain_value = 0


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, aliens_group, value, gain_value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, aliens_group, value, gain_value])


func get_args(player_index: int) -> Array:
    var size_value = value + int(Utils.get_stat(key_hash, player_index) * (gain_value / 100.0))

    var scene_id = aliens_group.wave_units_data[0].unit_scene_name.get_basename()
    var name_key: String = scene_id.to_upper() + "_NAME"
    var translated: String = tr(name_key)
    
    if translated == name_key:
        translated = scene_id
    
    return [
		"[color=lime]%s[/color]" % size_value,
		Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0),
		"[color=lime]%s[/color]" % translated
	]