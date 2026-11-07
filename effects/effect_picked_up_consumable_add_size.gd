class_name PickedUpConsumableAddSize
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：拾取消耗品增加体型
#   每次拾取消耗品增加角色体型。
#   运行时 custom_key：fengliu_picked_up_consumable_add_size
# ------------------------------------------------------------
# 效果值：
#   value  每次拾取体型增加的百分比（%）
# ============================================================


static func get_id() -> String:
	return "fengliu_picked_up_consumable_add_size"


# 数值累加 / 消费端遍历，异变复制有效
func fengliu_can_be_copied_by_mutation() -> bool:
	return true


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([value])


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0} 占位符：
	#   [0] = 每次拾取体型增加百分比（绿色）
	var args = .get_args(player_index)
	return [
		str(args[0])
	]