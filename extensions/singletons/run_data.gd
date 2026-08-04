extends "res://singletons/run_data.gd"


var effect_add_stat_after_change = Keys.generate_hash("add_stat_after_change")
var effect_add_stat_cap = Keys.generate_hash("add_stat_cap")
var effect_shop_item_count = Keys.generate_hash("shop_item_count")
var effect_picked_box_cost_gold_get_stat_or_weapon = Keys.generate_hash("picked_box_cost_gold_get_stat_or_weapon")
var stats_stop = Keys.generate_hash("stats_stop")


var levels = Keys.generate_hash("levels")


var stat_after_change_wave_value_count = {}


## 清除波次上限
func on_wave_start(timer: WaveTimer) -> void :
	for value_keys in stat_after_change_wave_value_count.keys():
		stat_after_change_wave_value_count[value_keys] = 0
	.on_wave_start(timer)
	

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
	
	var remainder_counts: Dictionary = effects[remainder_hash]
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
	

func add_stat(stat_hsh: int, value: int, player_index: int) -> void :
	check_stat(stat_hsh, value, player_index)
	.add_stat(stat_hsh, value, player_index)


func remove_stat(stat_hsh: int, value: int, player_index: int) -> void :
	check_stat(stat_hsh, -value, player_index)
	.remove_stat(stat_hsh, value, player_index)


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

	return int(get_stat(effects[0][0], player_index) * 40)


func remove_currency(value: int, player_index: int) -> void :
	var effects = get_player_effect(stats_stop, player_index)
	if effects.size() == 0:
		.remove_currency(value, player_index)
		return
	
	remove_stat(effects[0][0], int(ceil(value / float(effects[0][1]))), player_index)
