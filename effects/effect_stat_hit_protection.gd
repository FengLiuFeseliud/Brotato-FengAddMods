class_name StatHitProtection
extends Effect


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])


func get_args(player_index: int) -> Array:
    var args = .get_args(player_index)
    return [
        args[0],
        args[1],
        "[color=lime]+%s[/color]"  % int(Utils.get_stat(key_hash, player_index) / value)
    ]