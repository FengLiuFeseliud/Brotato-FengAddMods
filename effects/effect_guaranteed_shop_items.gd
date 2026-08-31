class_name GuaranteedShopItems
extends Effect


# ============================================================
# 效果：保证商店出现指定道具（类似 guaranteed_shop_items）
#   保证指定道具必定出现在商店中，替换随机商品；商店总数保持 4 个。
#   当玩家已拥有（含锁定道具）该道具达到其 max_nb 上限后，商店不再保证出现。
#   运行时 custom_key：fengliu_guaranteed_shop_items
# ------------------------------------------------------------
# 效果值：
#   key    要保证的道具 id，上限取自该道具的 max_nb
#   value  未使用
# ============================================================


func apply(player_index: int) -> void:
    RunData.get_player_effect(custom_key_hash, player_index).push_back([key_hash, value])


func unapply(player_index: int) -> void:
    RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])


func get_args(player_index: int) -> Array:
    # {0} = 道具名称
    return [ .get_args(player_index)[1] ]