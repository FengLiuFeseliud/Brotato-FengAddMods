extends "res://ui/menus/pages/menu_item_sets.gd"


# 物品套组页：沿用原版 tumor 判定，额外隐藏 ModItemData 标记的合成道具
func _is_hidden_in_item_set(item: ItemParentData) -> bool:
	return ._is_hidden_in_item_set(item) or ItemService.fengliu_is_hidden_in_codex(item)
