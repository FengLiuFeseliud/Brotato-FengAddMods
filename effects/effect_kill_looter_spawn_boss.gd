class_name KillLooterSpawnBoss
extends Effect


func apply(player_index: int) -> void:
    RunData.get_player_effect(custom_key_hash, player_index).push_back(value)


func unapply(player_index: int) -> void:
    RunData.get_player_effects(player_index)[custom_key_hash].erase(value)


func get_args(_player_index: int) -> Array:
    return [ "[color=lime]%s%%[/color]" % str(value) ]