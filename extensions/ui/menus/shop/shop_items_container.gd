extends "res://ui/menus/shop/shop_items_container.gd"


var effect_fengliu_stats_stop = Keys.generate_hash("fengliu_stats_stop")
var effect_fengliu_stats_buy_item = Keys.generate_hash("fengliu_stats_buy_item")
var effect_fengliu_temporary_stats_stop = Keys.generate_hash("fengliu_temporary_stats_stop")
var effect_fengliu_item_bought_spawn_boss = Keys.generate_hash("fengliu_item_bought_spawn_boss")

# 替代材料支付方式（fengliu_resolve_substitute_payment 的返回值）
const FENGLIU_PAY_NONE = 0          # 不接管，走原版金币流程
const FENGLIU_PAY_GOLD = 1          # 已扣金币（调用方需把价格归零）
const FENGLIU_PAY_STATS = 2         # 已扣属性（调用方需把价格归零）
const FENGLIU_PAY_BY_CURRENCY = 3   # RunData.remove_currency 会扣属性（不要归零）



func set_shop_items(items_data: Array) -> void :
	# 兜底补 roll：预报类效果即使没人刷新也会自愈
	var original: Array = items_data
	for entry in items_data:
		if entry == null or entry[0] == null:
			continue
		RunData.fengliu_ensure_item_roll(entry[0], player_index)

	# 旧版 base_shop 扩展生效时由它处理这些逻辑，避免重复计算
	if not fengliu_legacy_shop_extension_active():
		items_data = fengliu_apply_shop_modifications(items_data)

	# 防御：加工后若变成空表（异常情况），回退原始数据，避免商店整体空白
	if items_data == null or items_data.size() == 0:
		items_data = original

	.set_shop_items(items_data)


# 旧版 base_shop 扩展是否生效（生效时数量 / 价格 / 重随由它负责）
func fengliu_legacy_shop_extension_active() -> bool:
	var shop = fengliu_get_shop_node()
	return shop != null and shop.has_method("fengliu_roll_swap_enemies_in_shop")


# 向上找到 BaseShop 节点（数量裁剪需要同步它内部的 _shop_items 数据表）
func fengliu_get_shop_node() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("get_player_shop_items"):
			return node
		node = node.get_parent()
	return null


# 商店数据统一加工：格子数量 → 预报/套装武器重随 → 缺格加价
func fengliu_apply_shop_modifications(items_data: Array) -> Array:
	# 数量裁剪
	var result: Array = ItemService.fengliu_trim_shop_item_count(items_data, player_index)
	if result.size() != items_data.size():
		fengliu_sync_shop_data(result)

	# 预报 / 套装武器重随
	ItemService.fengliu_roll_shop_rerolls(result, player_index)

	# 缺格加价
	ItemService.fengliu_apply_shop_item_count_price(result, player_index)

	return result


# 把裁剪后的数据写回 BaseShop 内部表，保证锁格 / 重随 / 购买与显示一致
func fengliu_sync_shop_data(items_data: Array) -> void :
	var shop = fengliu_get_shop_node()
	if shop == null:
		return

	var shop_data = shop.get("_shop_items")
	if shop_data is Array and player_index < shop_data.size():
		shop_data[player_index] = items_data


func on_shop_item_buy_button_pressed(shop_item) -> void :
	if shop_item == null or shop_item.item_data == null:
		return
	if _is_delay_active:
		return

	if shop_item.item_data.get_category() == Category.CHARACTER and RunData.fengliu_shop_character_is_enabled(player_index):
		fengliu_buy_character_pending(shop_item)
		return


	if shop_item.item_data.get_category() == Category.WEAPON and not _can_weapon_be_bought(shop_item):
		return

	if shop_item.item_data.is_meca and shop_item.effect_choice_selected < 0:
		give_focus_to_mecha_choice(shop_item)
		return
		
	var payment: int = fengliu_resolve_substitute_payment(shop_item)
	var original_value: int = shop_item.value
	if payment == FENGLIU_PAY_GOLD or payment == FENGLIU_PAY_STATS:
		shop_item.value = 0
		.on_shop_item_buy_button_pressed(shop_item)
		shop_item.value = original_value
	else:
		.on_shop_item_buy_button_pressed(shop_item)

	if not shop_item.active and _is_delay_active:
		if payment == FENGLIU_PAY_STATS or payment == FENGLIU_PAY_BY_CURRENCY:
			fengliu_grant_stats_buy_item()
		fengliu_handle_item_bought_spawn_elite(shop_item)
		fengliu_handle_temporary_stats_stop()


func fengliu_resolve_substitute_payment(shop_item) -> int:
	var effects = RunData.get_player_effect(effect_fengliu_stats_stop, player_index)
	# 无替代材料效果：交给原版金币逻辑
	if effects.size() == 0:
		return FENGLIU_PAY_NONE

	var effect = effects[0]

	# 临时停表：remove_currency 会扣最高主属性，这里不插手
	var temp_stop_count = RunData.get_player_effect(effect_fengliu_temporary_stats_stop, player_index)
	if temp_stop_count > 0:
		return FENGLIU_PAY_BY_CURRENCY

	# alternative_coins == false：remove_currency 内部直接扣属性
	if not effect[2]:
		return FENGLIU_PAY_BY_CURRENCY

	# alternative_coins == true：金币足够则照常用金币
	if RunData.get_player_gold(player_index) >= shop_item.value:
		RunData.remove_gold(shop_item.value, player_index)
		return FENGLIU_PAY_GOLD

	# 金币不足则按汇率扣替代材料（属性）
	if RunData.get_player_currency(player_index) < shop_item.value:
		return FENGLIU_PAY_NONE

	var cost: int = int(ceil(shop_item.value / float(effect[1])))
	var current_stat: int = int(RunData.get_stat(effect[0], player_index))

	if current_stat - cost < 0:
		return FENGLIU_PAY_NONE

	RunData.remove_stat(effect[0], cost, player_index)
	return FENGLIU_PAY_STATS



func fengliu_grant_stats_buy_item() -> void :
	for add_effect in RunData.get_player_effect(effect_fengliu_stats_buy_item, player_index):
		RunData.add_stat(add_effect[0], add_effect[1], player_index)


# 是否买得起
func fengliu_can_afford(shop_item) -> bool:
	if RunData.get_player_gold(player_index) >= shop_item.value:
		return true
	return RunData.get_player_currency(player_index) >= shop_item.value


func fengliu_buy_character_pending(shop_item: ShopItem) -> void :
	# 金币或替代材料任一足够即可购买（alternative_coins == true 的角色金币优先）
	if not fengliu_can_afford(shop_item):
		emit_signal("shop_item_insufficient_currency", shop_item)
		return

	var shop = fengliu_get_shop_node()

	if shop != null:
		var shop_data = shop.get("_shop_items")
		if shop_data is Array and player_index < shop_data.size():
			for entry in shop_data[player_index]:
				if entry != null and entry.size() > 0 and entry[0] != null and entry[0].my_id == shop_item.item_data.my_id:
					shop_data[player_index].erase(entry)
					break

	var payment: int = fengliu_resolve_substitute_payment(shop_item)
	var charge_value: int = 0 if (payment == FENGLIU_PAY_GOLD or payment == FENGLIU_PAY_STATS) else shop_item.value
	RunData.remove_currency(charge_value, player_index)
	RunData.fengliu_add_pending_shop_character(shop_item.item_data, player_index)

	# 立即刷新背包，让待生效角色当场可见
	if shop != null and shop.has_method("_get_gear_container"):
		shop._get_gear_container(player_index).set_items_data(RunData.get_player_items(player_index))

	shop_item.deactivate()
	update_buttons_color()
	_is_delay_active = true


# 买指定道具刷精英（原 base_shop.fengliu_add_item_bought_elite）
func fengliu_handle_item_bought_spawn_elite(shop_item: ShopItem) -> void :
	for effect in RunData.get_player_effect(effect_fengliu_item_bought_spawn_boss, player_index):
		# 只处理配置了本道具的条目
		if shop_item.item_data.my_id_hash != effect[0]:
			continue

		var chance := 0.0
		# effect[2] 为每持有该道具的额外概率
		if effect[2] == 0:
			chance = effect[1]
		else:
			chance = (effect[1] + fengliu_get_item_count(effect[0]) * (effect[2] / 100.0)) / 100.0

		if not Utils.get_chance_success(chance):
			continue

		# 显示精英图标（原 base_shop.fengliu_add_icon_elite 的飘字效果）
		fengliu_add_icon_elite(shop_item)

		var rand_elite_id = ItemService.get_random_elite_id_hash_from_zone(ZoneService.current_zone.my_id)
		# 加入下一波精英
		RunData.get_player_effects(player_index)[Keys.extra_enemies_next_wave_hash].append(["res://zones/common/elite/group_elite.tres", 1, rand_elite_id])


# 显示精英图标飘字（商店节点上的 FloatingTextManagerShop）
func fengliu_add_icon_elite(shop_item) -> void :
	var shop = fengliu_get_shop_node()
	if shop == null or shop_item == null:
		return

	var floating_text_manager = shop.get("_floating_text_manager")
	if floating_text_manager == null or not floating_text_manager.has_method("display_shop_icon"):
		return

	var icon = ItemService.get_element(ItemService.icons, Keys.icon_elite_hash).icon
	var popup_pos = shop_item._steal_button.rect_global_position
	var direction: Vector2
	if RunData.is_coop_run:
		popup_pos.x -= 35
		direction = Vector2(0, - 30)
	else:
		popup_pos.x += shop_item._steal_button.rect_size.x / 2.0
		direction = Vector2(25, - 100)

	floating_text_manager.display_shop_icon(icon, popup_pos, direction)


# 临时停表：商店购买后按效果加属性并递减计数
func fengliu_handle_temporary_stats_stop() -> void :
	var temp_stop_count = RunData.get_player_effect(effect_fengliu_temporary_stats_stop, player_index)
	if temp_stop_count <= 0:
		return

	for add_effect in RunData.get_player_effect(effect_fengliu_stats_buy_item, player_index):
		RunData.add_stat(add_effect[0], add_effect[1], player_index)

	var player_effects = RunData.get_player_effects(player_index)
	player_effects[effect_fengliu_temporary_stats_stop] -= 1

	# 代付计数归零时刷新按钮显示
	if temp_stop_count - 1 <= 0:
		var shop = fengliu_get_shop_node()
		if shop != null and shop.has_method("_get_shop_items_container"):
			var items_container = shop._get_shop_items_container(player_index)
			if items_container != null:
				for child in items_container.get_children():
					if child is ShopItem and child.active and child.has_method("_fengliu_refresh_pay_display"):
						child._fengliu_refresh_pay_display()


# 统计玩家持有指定道具的数量
func fengliu_get_item_count(item_hash: int) -> int:
	var count := 0
	for item in RunData.get_player_items(player_index):
		if item != null and item.my_id_hash == item_hash:
			count += 1
	return count

	_buy_delay_timer.start()
