class_name StatsBuyItem
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：用属性购买道具时获得属性
#   用属性支付、金币不足购买道具时，获得指定属性（回馈）。
#   运行时 custom_key：fengliu_stats_buy_item
# ------------------------------------------------------------
# 效果值：
#   key    获得的属性
#   value  获得的数值
# ============================================================


static func get_id() -> String:
	return "fengliu_stats_buy_item"


# 数值累加 / 消费端遍历，异变复制有效
func fengliu_can_be_copied_by_mutation() -> bool:
	return true


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])