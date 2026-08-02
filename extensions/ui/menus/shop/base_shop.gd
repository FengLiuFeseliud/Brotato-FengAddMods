extends "res://ui/menus/shop/base_shop.gd"


var shop_item_count = Keys.generate_hash("shop_item_count")
var shop_item_count_price = Keys.generate_hash("effect_stat_item_price")
var shop_items_count_price = Keys.generate_hash("shop_items_count_price")

var shop_items_price = {}

static func get_dynamic_value(stat_min_value: int, stat_max_value: int, stat_no_zero: bool) -> int:
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	if dynamic_value == 0 and stat_no_zero:
		return get_dynamic_value(stat_min_value, stat_max_value, stat_no_zero)
	return dynamic_value


func set_item_count(player_locked_items: Array, shop_item_count: int, player_index: int) -> void:
	var can_shop_item_count = shop_item_count
	var player_locked_items_size = player_locked_items.size()

	if player_locked_items_size > shop_item_count:
		if player_locked_items_size == 4:
			can_shop_item_count = 4
		else:
			can_shop_item_count = player_locked_items_size + shop_item_count
			can_shop_item_count = 4 if can_shop_item_count > 4 else can_shop_item_count

	var new_items = []
	for index in range(can_shop_item_count):
		new_items.append(_shop_items[player_index][index])
	
	_shop_items[player_index] = new_items


func set_items_price_from_shop_item_count(price: int, player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	var new_price = price * (ItemService.NB_SHOP_ITEMS - _shop_items[player_index].size())
	if not effects.has(shop_items_count_price):
		effects[shop_items_count_price] = 0

	effects[Keys.items_price_hash] = effects[Keys.items_price_hash] + abs(effects[shop_items_count_price]) + new_price
	effects[shop_items_count_price] = new_price


func fill_shop_items(player_locked_items: Array, player_index: int, just_entered_shop: bool = false) -> void:
	var effects = RunData.get_player_effect(shop_item_count, player_index)
	if effects.size() == 0:
		.fill_shop_items(player_locked_items, player_index, just_entered_shop)
		return

	var effect = effects[0]
	.fill_shop_items(player_locked_items, player_index, just_entered_shop)
	if effect[1] > 0:
		return

	var new_shop_item_count = ItemService.NB_SHOP_ITEMS - get_dynamic_value(effect[2], effect[3], effect[4])
	set_item_count(player_locked_items, new_shop_item_count, player_index)
	if effect[5] == 0:
		return

	set_items_price_from_shop_item_count(effect[5], player_index)