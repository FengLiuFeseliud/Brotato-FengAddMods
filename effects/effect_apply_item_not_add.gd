class_name ApplyItemNotAddEffect
extends Effect


# ============================================================
# 效果：道具效果改写
#   拿到道具时，删除 / 反转 / 清除其（负面）属性效果。
#   运行时 custom_key：fengliu_stat_not_add
# ------------------------------------------------------------
# 效果值：
#   key                  要改写的具体属性效果（empty_hash 表示不指定，配合全清选项）
#   value                反转符号标志（>0 取绝对值变正，<0 变负）
#   reversal             是否反转（false 则直接删除该效果）
#   all_stats            是否删除所有主属性负面效果
#   all_secondary_stats  是否删除所有副属性负面效果
#   all_item_debuff      是否删除所有道具负面效果（持续掉血、无法回血等）
# ============================================================

export (bool) var reversal = false # 是否反转（false = 直接删除该效果）
export (bool) var all_stats = false # 是否删除所有主属性负面效果
export (bool) var all_secondary_stats = false # 是否删除所有副属性负面效果
export (bool) var all_item_debuff = false # 是否删除所有道具负面效果


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, reversal, all_stats, all_secondary_stats, all_item_debuff])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, reversal, all_stats, all_secondary_stats, all_item_debuff])