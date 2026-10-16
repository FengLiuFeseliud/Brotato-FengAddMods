extends "res://singletons/linked_stats.gd"


# 原版重算入口：先走原版，再按玩家结束本轮的 rebase 周期
func reset_player(player_index: int) -> void :
	.reset_player(player_index)

	# 未加载 mod 扩展时静默跳过（缺接口不算错误）
	if has_method("fengliu_clear_rebase_pending"):
		call("fengliu_clear_rebase_pending", player_index)
