class_name BossDiedRespawn
extends Effect


# ============================================================
# 效果：Boss 死亡重生
#   Boss 死亡后重新生成一个更强的 Boss。
#   运行时 custom_key：fengliu_boss_died_respawn
# ------------------------------------------------------------
# 效果值：
#   value  重生后 Boss 生命/伤害/速度的提升百分比（%）
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0} {1} 占位符：
	#   [0] = key 属性名（大写翻译）
	#   [1] = 重生属性提升百分比（绿色）
	var args = .get_args(player_index)
	return [
		args[1],
		"[color=lime]%s%%[/color]" % args[0]
	]