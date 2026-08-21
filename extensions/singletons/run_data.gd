extends "res://singletons/run_data.gd"


const ALL_SECONDARY_STATS = [
	"consumable_heal",
	"xp_gain",
	"effect_pickup_range",
	"explosion_size",
	"explosion_damage",
	"effect_bouncing",
	"piercing_damage",
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

	"hp_start_wave",
	"hp_start_next_wave"
]


const ALL_SECONDARY_ABS_DEBUFF_STATS = [
	"items_price",
	"reroll_price",
	
	"enemy_speed",
	"enemy_damage",
	"enemy_health"
]


const ALL_ITEM_DEBUFF = [
	"lose_hp_per_second",
	"no_heal",
	"extra_enemies_next_wave",
	"minimum_weapon_cooldowns",
	"hp_cap",
	"lock_current_weapons"
]


var effect_fengliu_add_stat_after_change = Keys.generate_hash("fengliu_add_stat_after_change")
var effect_fengliu_shop_item_count = Keys.generate_hash("fengliu_shop_item_count")
var effect_fengliu_stats_stop = Keys.generate_hash("fengliu_stats_stop")
var effect_fengliu_apply_item_not_add = Keys.generate_hash("fengliu_stat_not_add")
var effect_fengliu_item_merge = Keys.generate_hash("fengliu_item_merge")
var effect_fengliu_random_curse = Keys.generate_hash("fengliu_random_curse")
var effect_fengliu_wave_elites_spawn = Keys.generate_hash("fengliu_wave_elites_spawn")
var effect_fengliu_apply_item_not_add_all_debuff = Keys.generate_hash("fengliu_apply_item_not_add_all_debuff")


var stat_after_change_wave_value_count = {}
var all_secondary_stats_hashs = []
var all_secondary_abs_debuff_stats_hashs = []
var all_item_debuff_hashs = []
var _wave_total_hp_to_durations = [1.0, 1.0, 1.0]
var _wave_total_hp = 0

var _wave_intensity = 0
var _current_wave_intensity = 0
var _restart_wave = false


# 扩展初始化哈希列表
func _ready() -> void :
	# 生成次要属性哈希
	for secondary_stat in ALL_SECONDARY_STATS:
		all_secondary_stats_hashs.append(Keys.generate_hash(secondary_stat))

	# 生成道具负面效果哈希
	for item_debuff in ALL_ITEM_DEBUFF:
		all_item_debuff_hashs.append(Keys.generate_hash(item_debuff))

	# 生成绝对值负面属性哈希
	for item_debuff in ALL_SECONDARY_ABS_DEBUFF_STATS:
		all_secondary_abs_debuff_stats_hashs.append(Keys.generate_hash(item_debuff))


func fengliu_is_high_wave_intensity() -> bool:
	return (_current_wave_intensity / _wave_intensity) >= 1.8


func fengliu_get_wave_total_hp() -> float:
	return _wave_total_hp


func fengliu_get_wave_total_hp_to_duration() -> float:
	return _current_wave_intensity


# 生成波次精英
func fengliu_wave_elites_spawn(player_data) -> void :
	# 随机取一只精英
	var possible_elites = ItemService.get_elites_from_zone(current_zone)
	var new_elite_id = Utils.get_rand_element(possible_elites).my_id_hash
	# 加入下一波额外敌人
	player_data.effects[Keys.extra_enemies_next_wave_hash].append(["res://zones/common/elite/group_elite.tres", 1, new_elite_id])


# 获取玩家持有道具数量
func fengliu_get_item_count(item_hash: int, player_index: int) -> int:
	var count = 0
    
	# 统计指定道具数量
	for item in RunData.get_player_items(player_index):
		if item.my_id_hash == item_hash:
			count += 1
            
	return count


# 合并武器
func fengliu_merge_weapon(weapon_hash: int, player_index: int) -> bool:
	# 获取目标武器
	var merge_weapon = ItemService.get_element(ItemService.weapons, weapon_hash)
	if merge_weapon == null:
		return false
		
	var effects = RunData.get_player_effects(player_index)
	var weapons = RunData.get_player_weapons(player_index)

	# 槽位未满直接添加
	if weapons.size() < effects[Keys.weapon_slot_hash]:
		RunData.add_weapon(merge_weapon, player_index)
		return true

	# 槽满则升级同款武器
	for weapon in weapons:
		if weapon.weapon_id != merge_weapon.weapon_id:
			continue

		if weapon.tier >= merge_weapon.tier:
			continue
		
		RunData.remove_weapon(weapon, player_index)
		RunData.add_weapon(merge_weapon, player_index)
		return true

	return false


# 尝试合并道具
func fengliu_try_item_merge(item_merge_effect: Array, player_index: int) -> void:
	# 材料不足则跳过
	if fengliu_get_item_count(item_merge_effect[0], player_index) < item_merge_effect[1]:
		return
	
	# 第二种材料不足则跳过
	if item_merge_effect[3] != 0 and fengliu_get_item_count(item_merge_effect[2], player_index) < item_merge_effect[3]:
		return

	var item = ItemService.get_element(ItemService.items, item_merge_effect[4])
	if item == null and not fengliu_merge_weapon(item_merge_effect[4], player_index):
		return
	
	# 生成目标道具
	if item != null:
		for _index in range(item_merge_effect[5]):
			RunData.add_item(item, player_index)

	# 扣除材料
	for _index in range(item_merge_effect[1]):
		RunData.remove_item(ItemService.get_element(ItemService.items, item_merge_effect[0]), player_index)

	for _index in range(item_merge_effect[3]):
		RunData.remove_item(ItemService.get_element(ItemService.items, item_merge_effect[2]), player_index)


# 诅咒一个道具
func fengliu_curse_item(curse_item_effect: Array, player_index: int) -> bool:
	var dlc = ProgressData.get_dlc_data("abyssal_terrors")
	# 找一个可诅咒的道具
	for item in get_player_items(player_index):
		if item.is_cursed or item.my_id_hash in curse_item_effect[3] or item.get_category() == Category.CHARACTER:
			continue
		
		# 诅咒并替换
		var new_curse_item = dlc.curse_item(item, player_index, true)
		remove_item(item, player_index)
		add_item(new_curse_item, player_index)
		return true
	
	return false


# 诅咒一把武器
func fengliu_curse_weapon(curse_item_effect: Array, player_index: int) -> bool:
	var dlc = ProgressData.get_dlc_data("abyssal_terrors")
	# 找一把可诅咒的武器
	for weapon in get_player_weapons(player_index):
		if weapon.is_cursed or weapon.my_id_hash in curse_item_effect[3]:
			continue
		
		# 诅咒并替换
		var new_curse_weapon = dlc.curse_item(weapon, player_index, true)
		remove_weapon(weapon, player_index)
		add_weapon(new_curse_weapon, player_index)
		return true
	
	return false

	
# 自动诅咒道具或武器
func fengliu_auto_curse(curse_item_effect: Array, player_index: int) -> void:
	# 无 DLC 或材料不足则跳过
	if ProgressData.get_dlc_data("abyssal_terrors") == null or fengliu_get_item_count(curse_item_effect[0], player_index) < curse_item_effect[1]:
		return
		
	# 等级不足则跳过
	if get_player_level(player_index) < curse_item_effect[2]:
		return

	# 随机先诅咒道具或武器
	if Utils.get_chance_success(0.5):
		if not fengliu_curse_item(curse_item_effect, player_index):
			if not fengliu_curse_weapon(curse_item_effect, player_index):
				return
	else:
		if not fengliu_curse_weapon(curse_item_effect, player_index):
			if not fengliu_curse_item(curse_item_effect, player_index):
				return
	
	# 扣除材料道具
	for _index in range(curse_item_effect[1]):
		var curse_need_item = get_player_item(curse_item_effect[0], player_index)
		if curse_need_item == null:
			break
		remove_item(curse_need_item, player_index)
	
	var player_data = players_data[player_index]
	# 扣等级与经验
	player_data.current_level -= curse_item_effect[2]
	player_data.current_xp = max(0, player_data.current_xp - get_next_level_xp_needed(player_index))
	# 递归继续诅咒
	fengliu_auto_curse(curse_item_effect, player_index)


# 计算当前波次每秒平均生命值
func fengliu_calc_wave_total_hp_to_duration() -> float:
	# 获取本波数据
	var wave_data = ZoneService.get_wave_data(current_zone, current_wave)
	var total := 0

	# 遍历所有刷怪组
	for group in wave_data.groups_data:
		# 遍历组内刷怪单位
		for unit_data in group.wave_units_data:
			# 只统计敌人与 Boss
			if unit_data.type != EntityType.ENEMY and unit_data.type != EntityType.BOSS:
				continue

			# 无场景则跳过
			if unit_data.unit_scene == null:
				continue

			# 实例化敌人场景读取其基础属性
			var scene_inst = unit_data.unit_scene.instance()
			var stats = scene_inst.stats
			if stats == null:
				scene_inst.free()
				continue

			var base_hp = stats.get_base_health(current_wave)
			# 最终生命值
			var final_hp = EntityService.get_final_enemy_health(base_hp)

			# 期望生成数量 = 平均数量 * 生成概率
			var avg_count = (unit_data.min_number + unit_data.max_number) / 2.0 * unit_data.spawn_chance

			# 累加该单位的生命值贡献
			total += int(final_hp * avg_count)

			# 立即释放临时实例
			scene_inst.free()

	_wave_total_hp = total
	# 返回每秒平均生命值 = 总生命值 / 波次时长
	return total / float(max(1, wave_data.wave_duration))


# 扩展波次开始
func on_wave_start(timer: WaveTimer) -> void :
	## 清除波次上限
	for value_keys in stat_after_change_wave_value_count.keys():
		stat_after_change_wave_value_count[value_keys] = 0
	.on_wave_start(timer)

	# 注入精英
	for player_data in players_data:
		if player_data.effects.has(effect_fengliu_wave_elites_spawn) and player_data.effects[effect_fengliu_wave_elites_spawn].size() > 0:
			fengliu_wave_elites_spawn(player_data)


	if is_elite_wave(EliteType.ELITE) or is_elite_wave(EliteType.HORDE) or _restart_wave:
		return

	_current_wave_intensity = fengliu_calc_wave_total_hp_to_duration()
	
	var _wave_intensity_count = 0.0
	for _wave_total_hp_to_duration in _wave_total_hp_to_durations:
		_wave_intensity_count += _wave_total_hp_to_duration
	
	_wave_intensity = _wave_intensity_count / 3
	_wave_total_hp_to_durations.remove(0)
	_wave_total_hp_to_durations.append(_current_wave_intensity)


# 扩展波次结束
func on_wave_end() -> void :
	.on_wave_end()
	# 逐个玩家处理
	for player_index in get_player_count():
		# 处理道具合并
		var effects = get_player_effect(effect_fengliu_item_merge, player_index)
		if effects.size() > 0:
			for item_merge_effect in effects:
				fengliu_try_item_merge(item_merge_effect, player_index)

		# 处理自动诅咒
		effects = get_player_effect(effect_fengliu_random_curse, player_index)
		if effects.size() > 0:
			fengliu_auto_curse(effects[0], player_index)
	
	_restart_wave = false

## 统一添加效果 hsah
func get_player_effect(key: int, player_index: int):
	var effects = get_player_effects(player_index)
	if not effects.has(key):
		effects[key] = []
	
	assert (player_index >= 0, Keys.hash_to_string[key])
	return effects[key]
	

## 添加倍倍率修改
func fengliu_add_gain_stat(effect: Array, add_value: int, player_index: int):
	# 累加增益值
	get_player_effects(player_index)[effect[0]] += add_value
	

## 计算是否达到计数 达到返回计算值
func fengliu_calculate_add_value(effect: Array, value: int, player_index: int, effect_index: int) -> int:
	# 取计数阈值
	var scaled = effect[3]
	# 无计数则返回 0
	if scaled == 0:
		return 0
	
	# 计数为 1 直接按倍率返回
	if scaled == 1:
		return effect[1] * (value * RunData.get_stat_gain(effect[2], player_index))
	
	# 生成余数记录哈希
	var remainder_hash = Keys.generate_hash("add_stat_after_change_remainder_" + Keys.hash_to_string[effect[2]])
	var effects = get_player_effects(player_index)
	# 初始化余数记录
	if not effects.has(remainder_hash):
		effects[remainder_hash] = {}
	
	var remainder_counts = effects[remainder_hash]
	var remainder_key = str(effect[0]) + "_" + str(effect[2]) + "_" + str(effect_index)
	
	# 默认余数为 0
	var remainder = 0
	# 有上次余数则读取
	if remainder_counts.has(remainder_key):
		remainder = remainder_counts[remainder_key]
	
	# 累加本次值到余数
	var old_remainder = remainder + value * RunData.get_stat_gain(effect[2], player_index)
	# 计算触发次数
	var trigger_count = int(old_remainder / scaled)
	
	# 更新剩余余数
	remainder = old_remainder - (trigger_count * scaled)
	remainder_counts[remainder_key] = remainder
	get_player_effects(player_index)[remainder_hash] = remainder_counts
	# 返回触发次数 × 每次值
	return trigger_count * effect[1]


# 属性变化后追加属性
func fengliu_add_stat_after_change(effects: Array, stat_hsh: int, value: int, player_index: int) -> void:
	# 遍历追加效果
	for index in range(effects.size()):
		var effect = effects[index]
		# 非目标属性则跳过
		if stat_hsh != effect[2]:
			continue
		
		var add_value = fengliu_calculate_add_value(effect, value, player_index, index)
		if add_value == 0:
			continue
			
		# 应用每波转换上限
		add_value = fengliu_stat_after_change_wave_count(effect, add_value, player_index)
		if add_value == 0:
			continue

		# 按增益或直接添加
		if effect[-1]:
			fengliu_add_gain_stat(effect, add_value, player_index)
			continue
		
		add_stat(effect[0], add_value, player_index)


# 记录要移除的属性值
func fengliu_remove_stat_set(stat_hsh: int, value: int, player_index: int) -> void :
	var effects = get_player_effects(player_index)
	# 生成移除记录哈希
	var remove_stat_hash = Keys.generate_hash("remove_" + Keys.hash_to_string[stat_hsh])

	var remove_stat = 0
	if effects.has(remove_stat_hash) and effects[remove_stat_hash].size() > 0:
		remove_stat = effects[remove_stat_hash][0]
	
	# 累加需要移除的值
	get_player_effects(player_index)[remove_stat_hash] = [remove_stat + value]


# 属性减少时处理移除与追加
func fengliu_check_stat(stat_hsh: int, value: int, player_index: int) -> void :
	# 增加则无需处理
	if value >= 0:
		return 
	
	# 记录移除值
	fengliu_remove_stat_set(stat_hsh, int(abs(value)), player_index)
	var effects = RunData.get_player_effect(effect_fengliu_add_stat_after_change, player_index)
	if effects.size() == 0:
		return 
	
	# 触发后续追加
	fengliu_add_stat_after_change(effects, stat_hsh, int(abs(value)), player_index)
	return 
	

# 统计本波属性变化计数
func fengliu_stat_after_change_wave_count(stat_effect: Array, value: int, player_index: int):
	# 遍历追加效果
	for effect in RunData.get_player_effect(effect_fengliu_add_stat_after_change, player_index):
		var max_wave_count = effect[4]
		
		var stat_hsh = stat_effect[0]
		if effect[0] != stat_hsh or max_wave_count == 0:
			continue
		
		if not stat_after_change_wave_value_count.has(stat_hsh):
			stat_after_change_wave_value_count[stat_hsh] = 0
		
		# 已达本波上限
		if stat_after_change_wave_value_count[stat_hsh] >= max_wave_count:
			return 0
		
		# 累加本波计数
		stat_after_change_wave_value_count[stat_hsh] += value
		if stat_after_change_wave_value_count[stat_hsh] <= max_wave_count:
			return value
		
		return value - (stat_after_change_wave_value_count[stat_hsh] - max_wave_count)
	
	return value


# 扩展添加属性
func add_stat(stat_hsh: int, value: int, player_index: int) -> void :
	# 变化检查后调用原逻辑
	fengliu_check_stat(stat_hsh, value, player_index)
	.add_stat(stat_hsh, value, player_index)


# 扩展移除属性
func remove_stat(stat_hsh: int, value: int, player_index: int) -> void :
	# 变化检查后调用原逻辑
	fengliu_check_stat(stat_hsh, -value, player_index)
	.remove_stat(stat_hsh, value, player_index)


## fengliu_shop_item_count - 商店道具数效果 保留锁定数
func lock_player_shop_item(item_data: ItemParentData, wave_value: int, player_index: int) -> void :
	# 获取商店道具数效果
	var effects = RunData.get_player_effect(effect_fengliu_shop_item_count, player_index)
	# 无效果走原逻辑
	if effects.size() == 0:
		.lock_player_shop_item(item_data, wave_value, player_index)
		return
	
	# 已达锁定上限则不锁定
	if locked_shop_items[player_index].size() >= effects[0][6]:
		return
	
	# 执行锁定
	.lock_player_shop_item(item_data, wave_value, player_index)


# 扩展获取货币
func get_player_currency(player_index: int) -> int:
	# 无代付效果走原逻辑
	var effects = get_player_effect(effect_fengliu_stats_stop, player_index)
	if effects.size() == 0:
		return .get_player_currency(player_index)

	var effect = effects[0]
	# 按属性值折算货币
	return int(get_stat(effect[0], player_index) * effect[1])


# 扩展移除货币
func remove_currency(value: int, player_index: int) -> void :
	# 无代付效果走原逻辑
	var effects = get_player_effect(effect_fengliu_stats_stop, player_index)
	if effects.size() == 0:
		.remove_currency(value, player_index)
		return
	
	# 免费则跳过扣除
	if effects[0][2]:
		.remove_currency(0, player_index)
		return

	# 按属性值扣除
	remove_stat(effects[0][0], int(ceil(value / float(effects[0][1]))), player_index)


# 移除道具负面效果
func fengliu_remove_item_debuff(effects: Array) -> void:
	# 倒序移除道具负面效果
	for index in range(effects.size() - 1, -1, -1):
		var effect = effects[index]
		var effect_key_hash = effect.key_hash

		if effect_key_hash in all_item_debuff_hashs:
			effects.remove(index)

	
# 反转效果数值正负
func fengliu_reversal_effect_value(new_effect, abs_value: bool) -> Array:
	var modified_effect = new_effect.duplicate()
	# 效果属性反转
	if abs_value and modified_effect.value < 0:
		modified_effect.value = abs(new_effect.value)

	if not abs_value and modified_effect.value > 0:
		modified_effect.value = -modified_effect.value

	return modified_effect


# 移除或反转次要属性效果
func fengliu_remove_all_secondary_stats(new_effects: Array, reversal: bool = true) -> void:
	# 倒序遍历次要属性
	for index in range(new_effects.size() - 1, -1, -1):
		var effect = new_effects[index]
		var effect_key_hash = effect.key_hash

		# 非次要属性则跳过
		if not effect_key_hash in all_secondary_stats_hashs and not effect_key_hash in all_secondary_abs_debuff_stats_hashs:
			continue

		var effect_value = effect.value
		# 绝对值负面属性（敌人血量/速度/伤害）
		if effect_key_hash in all_secondary_abs_debuff_stats_hashs:
			# 负值正常保留
			if effect_value < 0:
				continue

			# 不移除则反转
			if not reversal:
				new_effects.remove(index)
			else:
				new_effects[index] = fengliu_reversal_effect_value(effect, false)
			continue

		# 普通次要属性负值处理
		if effect_value < 0:
			if not reversal:
				new_effects.remove(index)
			else:
				new_effects[index] = fengliu_reversal_effect_value(effect, true)


# 移除或反转主要属性负面
func fengliu_remove_all_stats(new_effects: Array, reversal: bool = false) -> void:
	# 倒序遍历主要属性
	for index in range(new_effects.size() - 1, -1, -1):
		var effect = new_effects[index]
		var effect_value = effect.value

		# 非主要属性或正值则跳过
		if not "stat_" in effect.key or effect_value > 0:
			continue

		if not reversal:
			new_effects.remove(index)
			continue

		new_effects[index] = fengliu_reversal_effect_value(effect, true)


# 移除道具全部负面效果
func fengliu_remove_all_item_debuff_effects(effects: Array):
	# 移除道具负面
	fengliu_remove_item_debuff(effects)
	# 移除次要属性负面
	fengliu_remove_all_secondary_stats(effects)
	# 移除主要属性负面
	fengliu_remove_all_stats(effects)


# 扩展应用道具效果
func apply_item_effects(item_data: ItemParentData, player_index: int) -> void :
	# 备份原效果
	var old_effects = item_data.effects.duplicate()
	var new_effects = item_data.effects.duplicate()

	# 固定修改效果
	for effect in RunData.get_player_effect(effect_fengliu_apply_item_not_add, player_index):
		# 移除主要属性负面
		if effect[3]:
			fengliu_remove_all_stats(new_effects, effect[2])

		# 移除次要属性负面
		if effect[4]:
			fengliu_remove_all_secondary_stats(new_effects, effect[2])

		# 移除道具负面
		if effect[5]:
			fengliu_remove_item_debuff(new_effects)

		# 无指定效果则跳过
		if effect[0] == Keys.empty_hash:
			continue

		# 匹配指定效果
		for index in range(new_effects.size() - 1, -1, -1):
			var item_effect = new_effects[index]
			if effect[0] != item_effect.key_hash:
				continue

			if not effect[2]:
				# 删除效果
				new_effects.remove(index)
				continue
			
			# 效果属性反转
			new_effects[index] = fengliu_reversal_effect_value(item_effect, effect[1] > 0)
			continue

	# 概率删除全部负面效果
	var effects = RunData.get_player_effect(effect_fengliu_apply_item_not_add_all_debuff, player_index)
	if effects.size() > 0 and not effects[0][1] and Utils.get_chance_success(effects[0][0] / 100.0):
		fengliu_remove_all_item_debuff_effects(new_effects)
	
	# 应用修改后效果
	item_data.effects = new_effects
	.apply_item_effects(item_data, player_index)
	# 还原效果
	item_data.effects = old_effects

func reset_to_start_wave_state() -> void :
	_restart_wave = true
	.reset_to_start_wave_state()