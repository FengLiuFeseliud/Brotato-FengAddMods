extends Weapon


var effect_fengliu_gain_random_killed_stat = Keys.generate_hash("fengliu_gain_random_killed_stat")
var effect_fengliu_weapon_killed_loot = Keys.generate_hash("fengliu_weapon_killed_loot")
var effect_fengliu_weapon_killed_health = Keys.generate_hash("fengliu_weapon_killed_health")
var effect_fengliu_wpapon_killed_add_temp_stat = Keys.generate_hash("fengliu_wpapon_killed_add_temp_stat")


var wave_gain = Keys.generate_hash("wave_gain")


# 随机生成动态值
static func fengliu_get_dynamic_value(stat_min_value: int, stat_max_value: int, stat_no_zero: bool) -> int:
	# 范围内随机取值
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	# 为 0 时重新取值
	if dynamic_value == 0 and stat_no_zero:
		return fengliu_get_dynamic_value(stat_min_value, stat_max_value, stat_no_zero)
	return dynamic_value


# 杀敌获取随机属性
func fengliu_gain_random_killed_stat(effect: NullEffect) -> void:
	# 未达到击杀数则跳过
	if _enemies_killed_this_wave_count % effect.value != 0:
		return
	
	# 随机取值并添加属性
	var random_val = fengliu_get_dynamic_value(effect.stat_min_value, effect.stat_max_value, effect.stat_no_zero)
	RunData.add_stat(effect.stat_hash, random_val, player_index)
	emit_signal("tracked_value_updated", random_val)


# 计算波次增益击杀阈值
func fengliu_wave_gain(effect: NullEffect) -> int:
	# 基础值 + 波次 * 每波增长
	var kill_count_value = effect.value + RunData.current_wave * effect.gain_value
	# 超过上限取上限
	return int(effect.cap_value if kill_count_value > effect.cap_value else kill_count_value)


# 生成一个消耗品
func fengliu_spawn_consumable(spawn_pos: Vector2) -> void:
	var main = get_tree().current_scene

	# 从对象池取消耗品
	var consumable = main.get_node_from_pool(main._consumable_pool_id, main._consumables_container)
	# 池中没有则新建
	if consumable == null:
	    consumable = main.consumable_scene.instance()
	    main._consumables_container.call_deferred("add_child", consumable)
	    var _error = consumable.connect("picked_up", main, "on_consumable_picked_up")
	    yield(consumable, "ready") 
	
	var consumable_data = ItemService.get_consumable_for_tier(Tier.UNCOMMON)
	consumable.already_picked_up = false
	consumable.consumable_data = consumable_data
	consumable.set_texture(consumable_data.icon)
    
	var dist = rand_range(200, 500) 
	var push_back_destination = ZoneService.get_rand_pos_in_area(spawn_pos, dist, 0)
	# 随机方向掉落
	consumable.drop(spawn_pos, 0, push_back_destination)
	
	main._consumables.push_back(consumable)
	emit_signal("tracked_value_updated", 1)


# 杀敌掉落箱子
func fengliu_weapon_killed_loot(effect: NullEffect, spawn_pos: Vector2) -> void:
	var kill_count_value = fengliu_wave_gain(effect)
	# 未达到击杀数则跳过
	if _enemies_killed_this_wave_count % kill_count_value != 0:
		return

	# 生成箱子
	fengliu_spawn_consumable(spawn_pos)


# 杀敌回复生命
func fengliu_weapon_killed_health(effect) -> void:
	# 计算触发概率（基础概率 + 属性倍率）
	var chance = effect.value + Utils.get_stat(effect.key_hash, player_index) * (effect.gain_value / 100.0)
	# 概率未命中则跳过
	if not Utils.get_chance_success(chance / 100.0):
		return
	
	# 计算回复量（基础值 + 属性倍率）
	var health = effect.health_value + int(Utils.get_stat(effect.health_gain_stat_hash, player_index) * (effect.health_gain_value / 100.0))
	# 对全部玩家回复生命
	for i in RunData.get_player_count():
		RunData.emit_signal("healing_effect", health, i, Keys.empty_hash)


# 杀敌添加临时属性
func fengliu_wpapon_killed_add_temp_stat(effect) -> void:
	# 计算触发概率（基础概率 + 属性倍率）
	var chance = effect.value + Utils.get_stat(effect.gain_stat_hash, player_index) * (effect.gain_value / 100.0)
	# 概率未命中则跳过
	if not Utils.get_chance_success(chance / 100.0):
		return

	TempStats.add_stat(effect.key_hash, effect.stat_nb, player_index)


# 扩展杀敌处理
func on_killed_something(_thing_killed: Node, hitbox: Hitbox) -> void :
	.on_killed_something(_thing_killed, hitbox)

	# 遍历武器效果
	for effect in effects:
		if effect.custom_key_hash == effect_fengliu_gain_random_killed_stat:
			# 杀敌获取随机值主要属性
			fengliu_gain_random_killed_stat(effect)
			continue

		if effect.custom_key_hash == effect_fengliu_weapon_killed_loot:
			# 杀敌获取箱子
			fengliu_weapon_killed_loot(effect, _thing_killed.global_position)
			continue

		if effect.custom_key_hash == effect_fengliu_weapon_killed_health:
			# 杀敌回复生命
			fengliu_weapon_killed_health(effect)
			continue

		# 杀敌添加临时属性
		if effect.custom_key_hash == effect_fengliu_wpapon_killed_add_temp_stat:
			fengliu_wpapon_killed_add_temp_stat(effect)
			continue

		
