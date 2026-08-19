class_name PickedUpConsumableAddSize
extends Effect


# ============================================================
# 效果：拾取消耗品增加体型
#   每次拾取消耗品增加角色体型。
#   运行时 custom_key：fengliu_picked_up_consumable_add_size
# ------------------------------------------------------------
# 效果值：
#   value  每次拾取体型增加的百分比（%）
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([value])


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0} 占位符：
	#   [0] = 每次拾取体型增加百分比（绿色）
	var args = .get_args(player_index)
	return [
		"[color=lime]%s%%[/color]" % args[0]
	]