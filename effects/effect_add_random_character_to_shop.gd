class_name AddRandomCharacterToShop
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：商店额外出现随机角色
#   商店刷新时按概率命中后，把一名随机角色加入商店格子（复用「额外商店道具」链路）。
#   角色与道具同为「ItemData」子类，可直接放进商店格。
#   运行时 custom_key：fengliu_add_random_character_to_shop
# ------------------------------------------------------------
# 效果值：
#   key         未使用
#   value       触发概率（百分比，例如 10 表示 10%）
#   shop_price  商店初始价格（基础价；0 = 用角色自身 value）
# ============================================================


export(int) var shop_price = 0


static func get_id() -> String:
	return "fengliu_add_random_character_to_shop"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back([key_hash, value, shop_price])


func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, shop_price])


func get_args(_player_index: int) -> Array:
	# {0} = 触发概率 {1} = 商店基础价
	return [str(value), str(shop_price)]
