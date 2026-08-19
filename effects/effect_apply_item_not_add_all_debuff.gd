class_name ApplyItemNotAddAllDebuff
extends Effect


# ============================================================
# 效果：概率删除全部负面效果
#   按概率删除道具（含箱子开出道具）的全部负面效果。
#   运行时 custom_key：fengliu_apply_item_not_add_all_debuff
# ------------------------------------------------------------
# 效果值：
#   value     触发概率（%）
#   from_box  是否作用于「箱子开出」的道具（true=箱子，false=普通拾取）
# ============================================================

export (bool) var from_box = false # true=作用于箱子开出的道具；false=普通拾取


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([value, from_box])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([value, from_box])


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0} 占位符：
	#   [0] = 触发概率百分比（绿色）
	var args = .get_args(player_index)
	return [
		"[color=lime]%s%%[/color]" % args[0]
	]