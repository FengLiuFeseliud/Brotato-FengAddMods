extends "res://ui/menus/shop/inventory.gd"


const FENGLIU_RAINBOW = preload("res://mods-unpacked/FengLiu-FengAddMods/ui/fengliu_unique/fengliu_rainbow_visuals.gd")


# 判断道具是否为不可叠加类型
func fengliu_is_one_element(element) -> bool:
	return element != null and element.get("one_elements") == true


# 扩展获取道具及持有数量
func get_elements_with_count(elements: Array) -> Array:
	# 区分不可叠加的道具与普通道具
	var one_element_items = []
	var other_elements = []
	for element in elements:
		# 仅持有不可叠加的道具单独处理
		if fengliu_is_one_element(element):
			one_element_items.append(element)
		else:
			other_elements.append(element)

	var result = []
	# 普通道具走原逻辑统计数量
	if other_elements.size() > 0:
		result = .get_elements_with_count(other_elements)

	# 仅不可叠加的道具固定数量为 1
	for element in one_element_items:
		result.append([element, 1])

	return result


# 扩展添加道具
func add_element(element: ItemParentData, check_for_duplicates: bool = false, sort_inventory: bool = true, _display_banned: float = 0, animated_entrance = false) -> void:
	# 仅持有不可叠加的道具不检查重复
	if fengliu_is_one_element(element):
		.add_element(element, false, sort_inventory, _display_banned, animated_entrance)
	else:
		.add_element(element, check_for_duplicates, sort_inventory, _display_banned, animated_entrance)


# 独特武器：库存格右上→左下彩虹边框
func _spawn_element(element: Resource, p_display_banned: float = 0, animated_entrance = false) -> InventoryElement:
	var instance = ._spawn_element(element, p_display_banned, animated_entrance)

	if FENGLIU_RAINBOW.is_unique(element):
		FENGLIU_RAINBOW.apply_border(instance, 0.0, 8.0)

	return instance
