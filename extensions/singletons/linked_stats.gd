extends "res://singletons/linked_stats.gd"


func reset_player(player_index: int) -> void :
	.reset_player(player_index)

	if has_method("fengliu_clear_rebase_pending"):
		call("fengliu_clear_rebase_pending", player_index)
