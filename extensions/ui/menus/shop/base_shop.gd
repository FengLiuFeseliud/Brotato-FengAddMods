extends BaseShop


var effect_fengliu_shop_item_count = Keys.generate_hash("fengliu_shop_item_count")
var effect_fengliu_stats_stop = Keys.generate_hash("fengliu_stats_stop")
var effect_fengliu_stats_buy_item = Keys.generate_hash("fengliu_stats_buy_item")
var effect_fengliu_item_bought_spawn_boss = Keys.generate_hash("fengliu_item_bought_spawn_boss")
var effect_fengliu_swap_enemie = Keys.generate_hash("fengliu_swap_enemie")
var effect_fengliu_get_fixed_upgrade = Keys.generate_hash("fengliu_get_fixed_upgrade")


var fengliu_shop_items_count_price = Keys.generate_hash("fengliu_shop_items_count_price")


var shop_items_price = {}

var need_reroll_effect = [
	effect_fengliu_swap_enemie,
	effect_fengliu_get_fixed_upgrade
]


# 随机生成动态值
static func fengliu_get_dynamic_value(stat_min_value: int, stat_max_value: int, stat_no_zero: bool) -> int:
	# 范围内随机取值
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	# 为 0 时重新取值
	if dynamic_value == 0 and stat_no_zero:
		return fengliu_get_dynamic_value(stat_min_value, stat_max_value, stat_no_zero)
	return dynamic_value


# 获取玩家持有道具数量
func fengliu_get_item_count(item_hash: int, player_index: int) -> int:
	var count = 0
	# 统计指定道具数量
	for item in RunData.get_player_items(player_index):
		if item.my_id_hash == item_hash:
			count += 1
	return count


# 设置商店道具数量
func fengliu_set_item_count(player_locked_items: Array, item_count: int, player_index: int) -> void:
	var player_locked_items_size = player_locked_items.size()

	# 计算最终道具数量
	if player_locked_items_size > item_count:
		if player_locked_items_size == 4:
			item_count = 4
		else:
			item_count = player_locked_items_size + item_count
			item_count = 4 if item_count > 4 else item_count

	# 截取前 item_count 个道具
	var new_items = []
	for index in range(item_count):
		new_items.append(_shop_items[player_index][index])
	
	_shop_items[player_index] = new_items


# 按商店道具数量调整价格
func fengliu_set_items_price_from_shop_item_count(price: int, player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	# 按缺失道具数加价
	var new_price = price * (ItemService.NB_SHOP_ITEMS - _shop_items[player_index].size())
	if not effects.has(fengliu_shop_items_count_price):
		effects[fengliu_shop_items_count_price] = 0

	effects[Keys.items_price_hash] = effects[Keys.items_price_hash] + abs(effects[fengliu_shop_items_count_price]) + new_price
	effects[fengliu_shop_items_count_price] = new_price


# 扩展填充商店道具
func fill_shop_items(player_locked_items: Array, player_index: int, just_entered_shop: bool = false) -> void:
	var effects = RunData.get_player_effect(effect_fengliu_shop_item_count, player_index)
	# 无效果则走原逻辑
	if effects.size() == 0:
		.fill_shop_items(player_locked_items, player_index, just_entered_shop)
		# 刷新预报道具的敌人替换
		fengliu_roll_swap_enemies_in_shop(player_index)
		return

	var effect = effects[0]
	.fill_shop_items(player_locked_items, player_index, just_entered_shop)
	# 固定数量
	if effect[3] == 0:
		fengliu_set_item_count(player_locked_items, effect[1], player_index)
	else:
		var new_shop_item_count = ItemService.NB_SHOP_ITEMS - fengliu_get_dynamic_value(effect[2], effect[3], effect[4])
		fengliu_set_item_count(player_locked_items, new_shop_item_count, player_index)

	# 刷新预报道具的敌人替换
	fengliu_roll_swap_enemies_in_shop(player_index)

	# 无需调整价格
	if effect[5] == 0:
		return
	fengliu_set_items_price_from_shop_item_count(effect[5], player_index)


# 商店刷新时触发预报道具的敌人替换
func fengliu_roll_swap_enemies_in_shop(player_index: int) -> void:
	# 遍历商店道具
	for shop_entry in _shop_items[player_index]:
		var item = shop_entry[0]
		if item.effects == null:
			continue

		var has_swap_effect = false
		for effect in item.effects:
			if effect.custom_key_hash in need_reroll_effect:
				has_swap_effect = true
				break
		if not has_swap_effect:
			continue

		var new_item = item.duplicate()
		var new_effects = []
		for effect in item.effects:
			if effect.custom_key_hash in need_reroll_effect:
				new_effects.append(effect.duplicate())
			else:
				new_effects.append(effect)
		new_item.effects = new_effects
		shop_entry[0] = new_item

		for effect in new_item.effects:
			if effect.custom_key_hash in need_reroll_effect:
				effect.fengliu_roll_effect(player_index)


# 显示精英图标
func fengliu_add_icon_elite(shop_item: ShopItem) -> void :
	var icon = ItemService.get_element(ItemService.icons, Keys.icon_elite_hash).icon
	var popup_pos = shop_item._steal_button.rect_global_position
	var direction: Vector2

	# 联机调整图标位置
	if RunData.is_coop_run:
		popup_pos.x -= 35
		direction = Vector2(0, - 30)
	else:
		popup_pos.x += shop_item._steal_button.rect_size.x / 2.0
		direction = Vector2(25, - 100)

	# 显示精英图标
	_floating_text_manager.display_shop_icon(icon, popup_pos, direction)


# 购买道具生成精英
func fengliu_add_item_bought_elite(effect: Array, shop_item: ShopItem, player_index: int) -> void:
	var chance = 0.0
	# 计算生成精英概率
	if effect[2] == 0:
		chance = effect[1]
	else:
		chance = (effect[1] + fengliu_get_item_count(shop_item.item_data.my_id_hash, player_index) * (effect[2] / 100.0)) / 100.0

	# 未命中则返回
	if not Utils.get_chance_success(chance):
		return
	
	fengliu_add_icon_elite(shop_item)
	var rand_elite_id = ItemService.get_random_elite_id_hash_from_zone(ZoneService.current_zone.my_id)
	# 加入下一波精英
	RunData.get_player_effects(player_index)[Keys.extra_enemies_next_wave_hash].append(["res://zones/common/elite/group_elite.tres", 1, rand_elite_id])


# 扩展属性代付购买
func on_shop_item_bought(shop_item: ShopItem, player_index: int) -> void :
	# 购买指定道具生成精英
	for effect in RunData.get_player_effect(effect_fengliu_item_bought_spawn_boss, player_index):
		if shop_item.item_data.my_id_hash == effect[0]:
			fengliu_add_item_bought_elite(effect, shop_item, player_index)

	# 无代付则走原逻辑
	var effects = RunData.get_player_effect(effect_fengliu_stats_stop, player_index)
	if effects.size() == 0 or not effects[0][2]:
		.on_shop_item_bought(shop_item, player_index)
		return

	# 金币足够则正常购买
	var gold = RunData.get_player_gold(player_index)
	if gold >= shop_item.value:
		RunData.remove_gold(shop_item.value, player_index)
		.on_shop_item_bought(shop_item, player_index)
		return

	# 购买前加属性
	for effect in RunData.get_player_effect(effect_fengliu_stats_buy_item, player_index):
		RunData.add_stat(effect[0], effect[1], player_index)

	var effect = effects[0]
	var currency = RunData.get_player_currency(player_index)
	var stat_value = int(ceil(shop_item.value / float(effect[1])))
	# 属性不够则扣属性代付
	if currency < shop_item.value:
		RunData.remove_stat(effect[0], currency, player_index)
		.on_shop_item_bought(shop_item, player_index)
		return

	RunData.remove_stat(effect[0], stat_value, player_index)
	.on_shop_item_bought(shop_item, player_index)