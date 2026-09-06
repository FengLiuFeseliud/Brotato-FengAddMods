class_name GoldStats
extends Effect


export (int) var stat_nb = 0


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, stat_nb])


func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, stat_nb])


func get_args(player_index: int) -> Array:
    var args = .get_args(player_index)

    return [
        "[color=lime]%s%%[/color]" % args[0],
        "[color=lime]+%s[/color]" % stat_nb if stat_nb > 0 else "[color=lime]%s[/color]" % stat_nb,
        args[1]
    ]