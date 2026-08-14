extends "res://ui/menus/shop/base_shop.gd"


var shop_item_count = Keys.generate_hash("shop_item_count")
var shop_item_count_price = Keys.generate_hash("effect_stat_item_price")
var shop_items_count_price = Keys.generate_hash("shop_items_count_price")
var stats_stop = Keys.generate_hash("stats_stop")
var stats_buy_item = Keys.generate_hash("stats_buy_item")
var effect_item_bought_spawn_boss = Keys.generate_hash("item_bought_spawn_boss")

var shop_items_price = {}

static func get_dynamic_value(stat_min_value: int, stat_max_value: int, stat_no_zero: bool) -> int:
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	if dynamic_value == 0 and stat_no_zero:
		return get_dynamic_value(stat_min_value, stat_max_value, stat_no_zero)
	return dynamic_value


func get_item_count(item_hash: int, player_index: int) -> int:
	var count = 0
	for item in RunData.get_player_items(player_index):
		if item.my_id_hash == item_hash:
			count += 1
	return count


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


func add_icon_elite(shop_item: ShopItem) -> void :
	var icon = ItemService.get_element(ItemService.icons, Keys.icon_elite_hash).icon
	var popup_pos = shop_item._steal_button.rect_global_position
	var direction: Vector2

	if RunData.is_coop_run:
		popup_pos.x -= 35
		direction = Vector2(0, - 30)
	else:
		popup_pos.x += shop_item._steal_button.rect_size.x / 2.0
		direction = Vector2(25, - 100)

	_floating_text_manager.display_shop_icon(icon, popup_pos, direction)


func add_item_bought_elite(effect: Array, shop_item: ShopItem, player_index: int) -> void:
	var chance = 0
	if effect[2] == 0:
		chance = effect[1]
	else:
		chance = (effect[1] + get_item_count(shop_item.item_data.my_id_hash, player_index) * (effect[2] / 100.0)) / 100.0

	if not Utils.get_chance_success(chance):
		return
	
	add_icon_elite(shop_item)
	var rand_elite_id = ItemService.get_random_elite_id_hash_from_zone(ZoneService.current_zone.my_id)
	RunData.get_player_effects(player_index)[Keys.extra_enemies_next_wave_hash].append(["res://zones/common/elite/group_elite.tres", 1, rand_elite_id])


func on_shop_item_bought(shop_item: ShopItem, player_index: int) -> void :
	for effect in RunData.get_player_effect(effect_item_bought_spawn_boss, player_index):
		if shop_item.item_data.my_id_hash == effect[0]:
			add_item_bought_elite(effect, shop_item, player_index)

	var effects = RunData.get_player_effect(stats_stop, player_index)
	if effects.size() == 0 or not effects[0][2]:
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