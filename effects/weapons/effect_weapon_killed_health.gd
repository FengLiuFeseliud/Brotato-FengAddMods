class_name WeaponKilledHealth
extends NullEffect


export (int) var gain_value = 0
export (int) var health_value = 1
export (String) var health_gain_stat = ""
export (int) var health_gain_value = 0
var health_gain_stat_hash


static func get_dynamic_chance(init_chance: int, add_chance: int = 100, stat_count: int = 0) -> int:
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	if dynamic_chance > 100:
		return 100
		
	return dynamic_chance


func _generate_hashes() -> void:
	._generate_hashes()
	health_gain_stat_hash = Keys.generate_hash(health_gain_stat)


func get_args(player_index: int) -> Array:
    var chance = get_dynamic_chance(value, gain_value, Utils.get_stat(key_hash, player_index))
    if chance > 100:
        chance = 100
    
    var health = health_value + int(Utils.get_stat(health_gain_stat_hash, player_index) * (health_gain_value / 100.0))
    return [
        "[color=lime]%s%%[/color]" % chance, 
        Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0),
        str(health),
        Utils.get_scaling_stat_icon_text(health_gain_stat_hash, health_gain_value / 100.0)
    ]   


