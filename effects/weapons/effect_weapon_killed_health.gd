class_name WeaponKilledHealth
extends NullEffect


export (int) var gain_value = 0
export (int) var health_value = 1
export (String) var health_gain_stat = ""
export (int) var health_gain_value = 0
var health_gain_stat_hash


func _generate_hashes() -> void:
	._generate_hashes()
	health_gain_stat_hash = Keys.generate_hash(health_gain_stat)


func get_args(player_index: int) -> Array:
    var dynamic_chance = value + (Utils.get_stat(key_hash, player_index) * (gain_value / 100.0))
    if dynamic_chance > 100:
        dynamic_chance = 100
    
    var health = health_value + int(Utils.get_stat(health_gain_stat_hash, player_index) * (health_gain_value / 100.0))
    return [
        "[color=lime]%s%%[/color]" % dynamic_chance, 
        Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0),
        str(health),
        Utils.get_scaling_stat_icon_text(health_gain_stat_hash, health_gain_value / 100.0)
    ]  