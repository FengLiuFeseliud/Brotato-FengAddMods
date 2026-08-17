extends "res://singletons/run_data.gd"


const ALL_SECONDARY_STATS = [
	"consumable_heal",
	"xp_gain",
	"effect_pickup_range",
	"items_price",
	"explosion_size",
	"explosion_damage",
	"effect_bouncing",
	"effect_piercing_damage",
	"damage_against_bosses",
	"structure_attack_speed",
	"structure_range",
	"burning_cooldown_reduction",
	"burning_spread",
	"knockback",
	"chance_double_gold",
	"free_rerolls",
	"trees",
	"number_of_enemies",
	"enemy_speed",
	"reroll_price",

	"hp_start_wave"
]


const ALL_ITEM_DEBUFF = [
	"lose_hp_per_second",
	"no_heal",
	"extra_enemies_next_wave",
	"minimum_weapon_cooldowns",
	"hp_cap",
	"lock_current_weapons"
]


var effect_add_stat_after_change = Keys.generate_hash("add_stat_after_change")
var effect_add_stat_cap = Keys.generate_hash("add_stat_cap")
var effect_shop_item_count = Keys.generate_hash("shop_item_count")
var effect_picked_box_cost_gold_get_stat_or_weapon = Keys.generate_hash("picked_box_cost_gold_get_stat_or_weapon")
var stats_stop = Keys.generate_hash("stats_stop")
var effect_stat_not_add = Keys.generate_hash("stat_not_add")
var effect_apply_item_not_add = Keys.generate_hash("apply_item_not_add")
var effect_item_merge = Keys.generate_hash("item_merge")
var effect_random_curse = Keys.generate_hash("random_curse")
var effect_wave_elites_spawn = Keys.generate_hash("wave_elites_spawn")
var effect_apply_item_not_add_all_debuff = Keys.generate_hash("apply_item_not_add_all_debuff")


var levels = Keys.generate_hash("levels")


var stat_after_change_wave_value_count = {}
var all_secondary_stats_hashs = []
var all_item_debuff_hashs = []


func _ready() -> void :
	for secondary_stat in ALL_SECONDARY_STATS:
		all_secondary_stats_hashs.append(Keys.generate_hash(secondary_stat))

	for item_debuff in ALL_ITEM_DEBUFF:
		all_item_debuff_hashs.append(Keys.generate_hash(item_debuff))


func wave_elites_spawn(player_data) -> void :
	var possible_elites = ItemService.get_elites_from_zone(current_zone)
	var new_elite_id = Utils.get_rand_element(possible_elites).my_id_hash
	player_data.effects[Keys.extra_enemies_next_wave_hash].append(["res://zones/common/elite/group_elite.tres", 1, new_elite_id])


func on_wave_start(timer: WaveTimer) -> void :
	## 清除波次上限
	for value_keys in stat_after_change_wave_value_count.keys():
		stat_after_change_wave_value_count[value_keys] = 0
	.on_wave_start(timer)

	for player_data in players_data:
		if player_data.effects.has(effect_wave_elites_spawn) and player_data.effects[effect_wave_elites_spawn].size() > 0:
			wave_elites_spawn(player_data)

func get_item_count(item_hash: int, player_index: int) -> int:
	var count = 0
    
	for item in RunData.get_player_items(player_index):
		if item.my_id_hash == item_hash:
			count += 1
            
	return count


func merge_weapon(weapon_hash: int, player_index: int) -> bool:
	var merge_weapon = ItemService.get_element(ItemService.weapons, weapon_hash)
	if merge_weapon == null:
		return false
		
	var effects = RunData.get_player_effects(player_index)
	var weapons = RunData.get_player_weapons(player_index)

	if weapons.size() < effects[Keys.weapon_slot_hash]:
		RunData.add_weapon(merge_weapon, player_index)
		return true

	for weapon in weapons:
		if weapon.weapon_id != merge_weapon.weapon_id:
			continue

		if weapon.tier >= merge_weapon.tier:
			continue
		
		RunData.remove_weapon(weapon, player_index)
		RunData.add_weapon(merge_weapon, player_index)
		return true

	return false


func try_item_merge(item_merge_effect: Array, player_index: int) -> void:
	if get_item_count(item_merge_effect[0], player_index) < item_merge_effect[1]:
		return
	
	if item_merge_effect[3] != 0 and get_item_count(item_merge_effect[2], player_index) < item_merge_effect[3]:
		return

	var item = ItemService.get_element(ItemService.items, item_merge_effect[4])
	if item == null and not merge_weapon(item_merge_effect[4], player_index):
		return
	
	if item != null:
		for _index in range(item_merge_effect[5]):
			RunData.add_item(item, player_index)

	for _index in range(item_merge_effect[1]):
		RunData.remove_item(ItemService.get_element(ItemService.items, item_merge_effect[0]), player_index)

	for _index in range(item_merge_effect[3]):
		RunData.remove_item(ItemService.get_element(ItemService.items, item_merge_effect[2]), player_index)


func curse_item(curse_item_effect: Array, player_index: int) -> bool:
	var dlc = ProgressData.get_dlc_data("abyssal_terrors")
	for item in get_player_items(player_index):
		if item.is_cursed or item.my_id_hash in curse_item_effect[3] or item.get_category() == Category.CHARACTER:
			continue
		
		var new_curse_item = dlc.curse_item(item, player_index, true)
		remove_item(item, player_index)
		add_item(new_curse_item, player_index)
		return true
	
	return false


func curse_weapon(curse_item_effect: Array, player_index: int) -> bool:
	var dlc = ProgressData.get_dlc_data("abyssal_terrors")
	for weapon in get_player_weapons(player_index):
		if weapon.is_cursed or weapon.my_id_hash in curse_item_effect[3]:
			continue
		
		var new_curse_weapon = dlc.curse_item(weapon, player_index, true)
		remove_weapon(weapon, player_index)
		add_weapon(new_curse_weapon, player_index)
		return true
	
	return false

	
func auto_curse(curse_item_effect: Array, player_index: int) -> void:
	if ProgressData.get_dlc_data("abyssal_terrors") == null or get_item_count(curse_item_effect[0], player_index) < curse_item_effect[1]:
		return
		
	if get_player_level(player_index) < curse_item_effect[2]:
		return

	if Utils.get_chance_success(0.5):
		if not curse_item(curse_item_effect, player_index):
			if not curse_weapon(curse_item_effect, player_index):
				return
	else:
		if not curse_weapon(curse_item_effect, player_index):
			if not curse_item(curse_item_effect, player_index):
				return
	
	for _index in range(curse_item_effect[1]):
		var curse_need_item = get_player_item(curse_item_effect[0], player_index)
		if curse_need_item == null:
			break
		remove_item(curse_need_item, player_index)
	
	var player_data = players_data[player_index]
	player_data.current_level -= curse_item_effect[2]
	player_data.current_xp = max(0, player_data.current_xp - get_next_level_xp_needed(player_index))
	auto_curse(curse_item_effect, player_index)


func on_wave_end() -> void :
	.on_wave_end()
	for player_index in get_player_count():
		var effects = get_player_effect(effect_item_merge, player_index)
		if effects.size() > 0:
			for item_merge_effect in effects:
				try_item_merge(item_merge_effect, player_index)

		effects = get_player_effect(effect_random_curse, player_index)
		if effects.size() > 0:
			auto_curse(effects[0], player_index)
		

## 统一添加效果 hsah
func get_player_effect(key: int, player_index: int):
	var effects = get_player_effects(player_index)
	if not effects.has(key):
		effects[key] = []
	
	assert (player_index >= 0, Keys.hash_to_string[key])
	return effects[key]
	

## 添加倍倍率修改
func _add_gain_stat(effect: Array, add_value: int, player_index: int):
	var effects = get_player_effects(player_index)
	
	var _gain = 0.0
	var gain_stat = effect[0]
	if effects.has(gain_stat):
		_gain = effects[gain_stat]
	
	get_player_effects(player_index)[gain_stat] += stat_after_change_wave_count(effect, add_value, player_index)
	

## 计算是否达到计数 达到返回计算值
func _calculate_add_value(effect: Array, value: int, player_index: int, effect_index: int) -> int:
	var scaled = effect[3]
	if scaled == 0:
		return 0
	
	if scaled == 1:
		return effect[1] * (value * RunData.get_stat_gain(effect[2], player_index))
	
	var remainder_hash = Keys.generate_hash("add_stat_after_change_remainder_" + Keys.hash_to_string[effect[2]])
	var effects = get_player_effects(player_index)
	if not effects.has(remainder_hash):
		effects[remainder_hash] = {}
	
	var remainder_counts = effects[remainder_hash]
	var remainder_key = str(effect[0]) + "_" + str(effect[2]) + "_" + str(effect_index)
	
	var remainder = 0
	if remainder_counts.has(remainder_key):
		remainder = remainder_counts[remainder_key]
	
	var old_remainder = remainder + value * RunData.get_stat_gain(effect[2], player_index)
	var trigger_count = int(old_remainder / scaled)
	
	remainder = old_remainder - (trigger_count * scaled)
	remainder_counts[remainder_key] = remainder
	get_player_effects(player_index)[remainder_hash] = remainder_counts
	return trigger_count * effect[1]


func _add_stat_after_change(effects: Array, stat_hsh: int, value: int, player_index: int) -> void:
	for index in range(effects.size()):
		var effect = effects[index]
		if stat_hsh != effect[2]:
			continue
		
		var add_value = _calculate_add_value(effect, value, player_index, index)
		if add_value == 0:
			continue
			
		if effect[-1]:
			_add_gain_stat(effect, add_value, player_index)
			continue
		
		add_stat(effect[0], add_value, player_index)


func remove_stat_set(stat_hsh: int, value: int, player_index: int) -> void :
	var effects = get_player_effects(player_index)
	var remove_stat_hash = Keys.generate_hash("remove_" + Keys.hash_to_string[stat_hsh])

	var remove_stat = 0
	if effects.has(remove_stat_hash) and effects[remove_stat_hash].size() > 0:
		remove_stat = effects[remove_stat_hash][0]
	
	get_player_effects(player_index)[remove_stat_hash] = [remove_stat + value]


func check_stat(stat_hsh: int, value: int, player_index: int) -> void :
	if value >= 0:
		return 
	
	remove_stat_set(stat_hsh, int(abs(value)), player_index)
	var effects = RunData.get_player_effect(effect_add_stat_after_change, player_index)
	if effects.size() == 0:
		return 
	
	_add_stat_after_change(effects, stat_hsh, int(abs(value)), player_index)
	return 
	

func stat_after_change_wave_count(stat_effect: Array, value: int, player_index: int):
	for effect in RunData.get_player_effect(effect_add_stat_after_change, player_index):
		var max_wave_count = effect[4]
		
		var stat_hsh = stat_effect[0]
		if effect[0] != stat_hsh or max_wave_count == 0:
			continue
		
		if not stat_after_change_wave_value_count.has(stat_hsh):
			stat_after_change_wave_value_count[stat_hsh] = 0
		
		if stat_after_change_wave_value_count[stat_hsh] >= max_wave_count:
			return 0
		
		stat_after_change_wave_value_count[stat_hsh] += value
		if stat_after_change_wave_value_count[stat_hsh] <= max_wave_count:
			return value
		
		return value - (stat_after_change_wave_value_count[stat_hsh] - max_wave_count)
	
	return value


func reset_value(stat_hsh: int, value: int, player_index: int, remove: bool) -> int:
	for effect in get_player_effect(effect_stat_not_add, player_index):
		if effect[0] == stat_hsh and (value > 0 and !remove) or (value < 0 and remove):
			return 0
	
	return value

func add_stat(stat_hsh: int, value: int, player_index: int) -> void :
	check_stat(stat_hsh, value, player_index)
	.add_stat(stat_hsh, reset_value(stat_hsh, value, player_index, false), player_index)


func remove_stat(stat_hsh: int, value: int, player_index: int) -> void :
	check_stat(stat_hsh, -value, player_index)
	.remove_stat(stat_hsh, reset_value(stat_hsh, value, player_index, true), player_index)


## shop_item_count - 商店道具数效果 保留锁定数
func lock_player_shop_item(item_data: ItemParentData, wave_value: int, player_index: int) -> void :
	var effects = RunData.get_player_effect(effect_shop_item_count, player_index)
	if effects.size() == 0:
		.lock_player_shop_item(item_data, wave_value, player_index)
		return
	
	if locked_shop_items[player_index].size() >= effects[0][6]:
		return
	
	.lock_player_shop_item(item_data, wave_value, player_index)


func get_player_currency(player_index: int) -> int:
	var effects = get_player_effect(stats_stop, player_index)
	if effects.size() == 0:
		return .get_player_currency(player_index)

	var effect = effects[0]
	return int(get_stat(effect[0], player_index) * effect[1])


func remove_currency(value: int, player_index: int) -> void :
	var effects = get_player_effect(stats_stop, player_index)
	if effects.size() == 0:
		.remove_currency(value, player_index)
		return
	
	if effects[0][2]:
		.remove_currency(0, player_index)
		return

	remove_stat(effects[0][0], int(ceil(value / float(effects[0][1]))), player_index)


func remove_all_item_debuff_effects(effects: Array):
	for index in range(effects.size() - 1, -1, -1):
		var effect = effects[index]
		var effect_key_hash = effect.key_hash

		if effect_key_hash in all_item_debuff_hashs:
			effects.remove(index)
			continue
		
		var effect_value = effect.value
		if not effect_key_hash in all_secondary_stats_hashs and not "stat_" in effect.key:
			continue

		if Keys.items_price_hash == effect_key_hash and effect_value > 0:
			effects.remove(index)
			continue

		if Keys.enemy_speed_hash == effect_key_hash and effect_value > 0:
			effects.remove(index)
			continue

		if Keys.reroll_price_hash == effect_key_hash and effect_value > 0:
			effects.remove(index)
			continue

		if effect_value < 0:
			effects.remove(index)


func apply_item_effects(item_data: ItemParentData, player_index: int) -> void :
	var old_effects = item_data.effects.duplicate()
	var new_effects = item_data.effects.duplicate()

	# 固定修改效果
	for effect in RunData.get_player_effect(effect_apply_item_not_add, player_index):
		for index in range(new_effects.size() - 1, -1, -1):
			var item_effect = new_effects[index]
			if effect[0] != item_effect.key_hash and not (effect[3] and "stat_" in item_effect.key):
				continue

			if not effect[2]:
				# 删除效果
				new_effects.remove(index)
				continue
			
			var modified_effect = item_effect.duplicate()
			# 效果属性反转
			if effect[1] > 0 and modified_effect.value < 0:
				modified_effect.value = abs(item_effect.value)

			if effect[1] < 0 and modified_effect.value > 0:
				modified_effect.value = -modified_effect.value

			new_effects[index] = modified_effect
			continue

	# 概率删除全部负面效果
	var effects = RunData.get_player_effect(effect_apply_item_not_add_all_debuff, player_index)
	if effects.size() > 0 and not effects[0][1] and Utils.get_chance_success(effects[0][0] / 100.0):
		remove_all_item_debuff_effects(new_effects)
	
	item_data.effects = new_effects
	.apply_item_effects(item_data, player_index)
	item_data.effects = old_effects