class_name WpaponKilledAddTempStat
extends NullEffect


export (String) var gain_stat = ""
export (int) var gain_value = 0
export (int) var stat_nb = 1
var gain_stat_hash = 0


func _generate_hashes() -> void:
	._generate_hashes()
	gain_stat_hash = Keys.generate_hash(gain_stat)


func get_args(player_index: int) -> Array:
    var dynamic_chance = value + (Utils.get_stat(gain_stat_hash, player_index) * (gain_value / 100.0))
    if dynamic_chance > 100:
        dynamic_chance = 100

    return [
        "[color=lime]%s%%[/color]" % dynamic_chance, 
        Utils.get_scaling_stat_icon_text(gain_stat_hash, gain_value / 100.0),
        "[color=lime]+%s[/color]" % str(stat_nb),
        .get_args(player_index)[1]
    ]  