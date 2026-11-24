extends "res://ui/menus/pages/menu_codex.gd"


var _fengliu_visible_item_count: int = 0
var _fengliu_visible_item_unlocked: int = 0


# 基类建完列表后再做一次过滤，避免复制原版列表构建逻辑
func _pop():
	._pop()
	_fengliu_hide_marked_items()


# 跳过 ModItemData.hide_in_codex 标记的道具（合成材料等）
func _fengliu_hide_marked_items() -> void:
	var visible_items := []
	for child in inventory_items.get_children():
		var item = child.item
		if item != null and not ItemService.fengliu_is_hidden_in_codex(item):
			visible_items.append(item)

	_fengliu_visible_item_count = visible_items.size()
	_fengliu_visible_item_unlocked = 0
	for item in visible_items:
		if ProgressData.items_bought.has(item.my_id_hash):
			_fengliu_visible_item_unlocked += 1

	# 没有需要隐藏的道具时不重建，保持基类结果
	if visible_items.size() == inventory_items.get_child_count():
		return

	inventory_items.set_elements(visible_items)
	if inventory_items.get_child_count() > 0:
		inventory_items.on_element_focused(inventory_items.get_child(0))


# 基类分子统计含隐藏项，这里只统计可见项，避免百分比溢出或提前到 100%
func _on_but_tab_items_pressed():
	if _fengliu_visible_item_count <= 0:
		_update_progress_bar(0.0)
		return
	_update_progress_bar(float(_fengliu_visible_item_unlocked) / float(_fengliu_visible_item_count))
