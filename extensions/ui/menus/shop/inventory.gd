extends Inventory


# 判断道具是否为「仅持有 1 个」类型
func fengliu_is_one_element(element) -> bool:
	return element != null and element.get("one_elements") == true


# 扩展获取道具及持有数量
func get_elements_with_count(elements: Array) -> Array:
	# 区分「仅持有 1 个」的道具与普通道具
	var one_element_items = []
	var other_elements = []
	for element in elements:
		# 仅持有 1 个的道具单独处理
		if fengliu_is_one_element(element):
			one_element_items.append(element)
		else:
			other_elements.append(element)

	var result = []
	# 普通道具走原逻辑统计数量
	if other_elements.size() > 0:
		result = .get_elements_with_count(other_elements)

	# 仅持有 1 个的道具固定数量为 1
	for element in one_element_items:
		result.append([element, 1])

	return result


# 扩展添加道具（仅持有 1 个的道具不检查重复）
func add_element(element: ItemParentData, check_for_duplicates: bool = false, sort_inventory: bool = true, _display_banned: float = 0, animated_entrance = false) -> void:
	# 仅持有 1 个的道具不检查重复
	if fengliu_is_one_element(element):
		.add_element(element, false, sort_inventory, _display_banned, animated_entrance)
	else:
		.add_element(element, check_for_duplicates, sort_inventory, _display_banned, animated_entrance)
