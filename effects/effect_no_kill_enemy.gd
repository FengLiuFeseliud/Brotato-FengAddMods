class_name NoKillEnemy
extends Effect


# ============================================================
# 效果：攻击不致死
#   指定类型攻击无法击杀敌人，伤害最多将敌人生命降至 1。
#   运行时 custom_key：fengliu_no_kill_enemy
# ------------------------------------------------------------
# 效果值：
#   key  触发该效果的攻击类型（如 Structure = 构造物）
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key])


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0} 占位符：
	#   [0] = 触发该效果的攻击类型名（基类 args[1]）
	var args = .get_args(player_index)
	return [
		"[color=lime]%s[/color]" % args[1]
	]