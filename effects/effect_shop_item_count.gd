class_name ShopItemCountEffect
extends Effect

# ============================================================
# 效果：商店道具数效果
#   修改商店商品数量，并可影响价格与锁定保留。
#   运行时 custom_key：fengliu_shop_item_count
# ------------------------------------------------------------
# 效果值：
#   key               倍率属性（未被逻辑使用）
#   value             固定商品数（当 stat_max_value=0 时生效）
#   stat_min_value    随机减少的商品数下限
#   stat_max_value    随机减少的商品数上限（≠0 时，商品数 = 默认数 − 随机减少数）
#   stat_no_zero      随机减少数不能为 0
#   shop_count_price  每减少 1 个商品，商品总价的优惠百分比（%）
#   can_shop_locked   允许保留的锁定商品数量上限
# ============================================================

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
    # 返回数组按顺序填充描述文本 {0}~{4} 占位符：
    #   [0] = 固定商品数 (value)
    #   [1] = 随机减少商品数下限（绿色）
    #   [2] = 随机减少商品数上限（绿色）
    #   [3] = 每减少 1 个商品的优惠百分比（绿色）
    #   [4] = 保留锁定数上限（绿色）
    return [str(value), "[color=lime]%s[/color]" % stat_min_value, "[color=lime]%s[/color]" % stat_max_value, "[color=lime]%s%%[/color]" % shop_count_price, "[color=lime]%s[/color]" % can_shop_locked]