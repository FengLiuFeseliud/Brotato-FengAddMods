extends "res://ui/menus/shop/base_shop.gd"


var shop_item_count = Keys.generate_hash("shop_item_count")
var shop_item_count_price = Keys.generate_hash("effect_stat_item_price")
var shop_items_count_price = Keys.generate_hash("shop_items_count_price")
var stats_stop = Keys.generate_hash("stats_stop")
var stats_buy_item = Keys.generate_hash("stats_buy_item")

var shop_items_price = {}

static func get_dynamic_value(stat_min_value: int, stat_max_value: int, stat_no_zero: bool) -> int:
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	if dynamic_value == 0 and stat_no_zero:
		return get_dynamic_value(stat_min_value, stat_max_value, stat_no_zero)
	return dynamic_value


func set_item_count(player_locked_items: Array, item_count: int, player_index: int) -> void:
	var player_locked_items_size = player_locked_items.size()

	if player_locked_items_size > item_count:
		if player_locked_items_size == 4:
			item_count = 4
		else:
			item_count = player_locked_items_size + item_count
			item_count = 4 if item_count > 4 else item_count

	var new_items = []
	for index in range(item_count):
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
	if effect[3] == 0:
		set_item_count(player_locked_items, effect[1], player_index)
	else:
		var new_shop_item_count = ItemService.NB_SHOP_ITEMS - get_dynamic_value(effect[2], effect[3], effect[4])
		set_item_count(player_locked_items, new_shop_item_count, player_index)

	if effect[5] == 0:
		return
	set_items_price_from_shop_item_count(effect[5], player_index)


func on_shop_item_bought(shop_item: ShopItem, player_index: int) -> void :
	var effects = RunData.get_player_effect(stats_stop, player_index)
	if effects.size() == 0 and not effects[0][2]:
		.on_shop_item_bought(shop_item, player_index)
		return

	var gold = RunData.get_player_gold(player_index)
	if gold >= shop_item.value:
		RunData.remove_gold(shop_item.value, player_index)
		.on_shop_item_bought(shop_item, player_index)
		return

	for effect in RunData.get_player_effect(stats_buy_item, player_index):
		RunData.add_stat(effect[0], effect[1], player_index)

	var effect = effects[0]
	var currency = RunData.get_player_currency(player_index)
	var stat_value = int(ceil(shop_item.value / float(effect[1])))
	if currency < shop_item.value:
		RunData.remove_stat(effect[0], currency, player_index)
		.on_shop_item_bought(shop_item, player_index)
		return

	RunData.remove_stat(effect[0], stat_value, player_index)
	.on_shop_item_bought(shop_item, player_index)