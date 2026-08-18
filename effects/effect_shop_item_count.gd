class_name ShopItemCountEffect
extends Effect

# 商店道具数效果
# value 不为 0 时固定物品数

export (int) var stat_min_value # 随机物品数下限
export (int) var stat_max_value # 随机物品数上限
export (bool) var stat_no_zero = false # 随机没有 0
export (int) var shop_count_price = 0 # 减少一个道具时优惠多少
export (int) var can_shop_locked = 0 # 保留锁定数



func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, stat_min_value, stat_max_value, stat_no_zero, shop_count_price, can_shop_locked])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, stat_min_value, stat_max_value, stat_no_zero, shop_count_price, can_shop_locked])


func get_args(_player_index: int) -> Array:
    return [str(value), "[color=lime]%s[/color]" % stat_min_value, "[color=lime]%s[/color]" % stat_max_value, "[color=lime]%s%%[/color]" % shop_count_price, "[color=lime]%s[/color]" % can_shop_locked]