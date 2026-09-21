extends "res://singletons/linked_stats.gd"


func reset_player(player_index: int) -> void :
	.reset_player(player_index)

	# TempStats 扩展提供该接口；未继承到（理论上不会发生）时跳过
	if has_method("fengliu_clear_rebase_pending"):
		call("fengliu_clear_rebase_pending", player_index)
