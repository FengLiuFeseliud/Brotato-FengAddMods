extends Main


var effect_fengliu_can_add_chance_stat_damage_when_pickup_gold = Keys.generate_hash("fengliu_can_add_chance_stat_damage_when_pickup_gold")
var effect_fengliu_can_add_chance_stat_damage_when_death = Keys.generate_hash("fengliu_can_add_chance_stat_damage_when_death")
var effect_fengliu_random_stats_on_level_up = Keys.generate_hash("fengliu_random_stats_on_level_up")
var effect_fengliu_picked_box_cost_gold = Keys.generate_hash("fengliu_picke_box_cost_gold")
var effect_fengliu_picke_consumable_drop_structure = Keys.generate_hash("fengliu_picke_consumable_drop_structure")
var effect_fengliu_boss_died_respawn = Keys.generate_hash("fengliu_boss_died_respawn")
var effect_fengliu_killed_all_boss_wave_end = Keys.generate_hash("fengliu_killed_all_boss_wave_end")
var effect_fengliu_add_xp_gold_from_wave_time = Keys.generate_hash("fengliu_add_xp_gold_from_wave_time")
var effect_fengliu_auto_open_box = Keys.generate_hash("fengliu_auto_open_box")
var effect_fengliu_apply_item_not_add_all_debuff = Keys.generate_hash("fengliu_apply_item_not_add_all_debuff")


var _is_speedrun_ending: bool = false


static func get_dynamic_chance(stat_count: int, init_chance: int, add_chance: int) -> int:
	var dynamic_chance = int(init_chance + (stat_count * (add_chance / 100.0)))
	if dynamic_chance > 100:
		return 100
		
	return dynamic_chance


static func get_dynamic_chance_to_effect(effect: Array, player_index: int) -> Array:
	var stat = Utils.get_stat(effect[4], player_index)
	effect[2] = get_dynamic_chance(stat, effect[-1], effect[-2])
	return effect
	

static func get_dynamic_value(stat_min_value: int, stat_max_value: int, stat_no_zero: bool) -> int:
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	if dynamic_value == 0 and stat_no_zero:
		return get_dynamic_value(stat_min_value, stat_max_value, stat_no_zero)
	return dynamic_value


static func get_dynamic_value_from_gain(dynamic_value: int, stat_gain: int, stat_gain_value: int) -> int:
	return dynamic_value * (1 + (int(stat_gain / stat_gain_value)))
	

static func get_dynamic_value_to_effect(effect: Array, player_index: int) -> int:
	if effect[5] == 0:
		return get_dynamic_value(effect[1], effect[2], effect[3])
	
	return int(get_dynamic_value_from_gain(get_dynamic_value(effect[1], effect[2], effect[3]), RunData.get_stat(effect[4], player_index), effect[5]))


func on_gold_picked_up(gold: Node, player_index: int) -> void :
	if gold.already_picked_up:
		.on_gold_picked_up(gold, player_index)
		return
	
	if not player_index >= 0:
		.on_gold_picked_up(gold, player_index)
		return
		
	var effects = RunData.get_player_effect(effect_fengliu_can_add_chance_stat_damage_when_pickup_gold, player_index)
	if effects.size() == 0:
		.on_gold_picked_up(gold, player_index)
		return
	
	effects[0] = get_dynamic_chance_to_effect(effects[0], player_index)
	handle_stat_damages(effects, player_index)
	.on_gold_picked_up(gold, player_index)


func respawn_boss(enemy: Enemy, effect: Array) -> void:
	var gain_value = effect[1] / 100.0
	var old_health = enemy.max_stats.health
	var old_damage = enemy.max_stats.damage
	var old_speed = enemy.max_stats.speed
	var global_position = enemy.global_position
	var filename = enemy.filename

	yield(get_tree().create_timer(1.0), "timeout")

	if _cleaning_up:
		return

	var args = _entity_spawner.SpawnEntityArgs.new(global_position, EntityType.BOSS)
	var new_boss = _entity_spawner.spawn_entity(load(filename), args)

	var new_health = old_health + int(old_health * gain_value)
	if new_health < 30:
		new_health = 30

	new_boss.max_stats.health = new_health
	new_boss.current_stats.health = new_health
		
	var new_damage = old_damage + int(old_damage * gain_value)
	new_boss.max_stats.damage = new_damage
	new_boss.current_stats.damage = new_damage

	var new_speed = old_speed + int(old_speed * gain_value)
	new_boss.max_stats.damage = new_speed
	new_boss.current_stats.damage = new_speed


func _on_enemy_died(enemy: Enemy, args: Entity.DieArgs) -> void:
	for player in _get_shuffled_live_players(): 
		var effects = RunData.get_player_effect(effect_fengliu_killed_all_boss_wave_end, player.player_index)
		if effects.size() > 0 and _entity_spawner.get_nb_bosses_and_elites_alive() == 1 and enemy is Boss:
			._on_enemy_died(enemy, args)
			yield(get_tree().create_timer(1.0), "timeout")
			if _cleaning_up:
				return
				
			_on_WaveTimer_timeout()
			return

		effects = RunData.get_player_effect(effect_fengliu_boss_died_respawn, player.player_index)
		if enemy is Boss and effects.size() > 0:
			respawn_boss(enemy, effects[0])
	
	if _cleaning_up and args.enemy_killed_by_player or enemy is Boss:
		._on_enemy_died(enemy, args)
		return
	
	for player in _get_shuffled_live_players():
		var player_index = player.player_index
		var effects = RunData.get_player_effect(effect_fengliu_can_add_chance_stat_damage_when_death, player_index)
		if effects.size() > 0:
			effects[0] = get_dynamic_chance_to_effect(effects[0], player_index)
			handle_stat_damages(effects, player_index)
				
	._on_enemy_died(enemy, args)


func on_levelled_up(player_index: int) -> void :
	.on_levelled_up(player_index)
	
	var effects = RunData.get_player_effect(effect_fengliu_random_stats_on_level_up, player_index)
	for effect in effects:
		var stat_hash = effect[0]
		var random_add_value = get_dynamic_value_to_effect(effect, player_index) 
		if effect[4]:
			RunData.add_stat(stat_hash, random_add_value, player_index)
			return
			
		RunData.add_stat(stat_hash, random_add_value, player_index)

	
func add_weapon(player_index: int) -> WeaponData:
	var effects = RunData.get_player_effects(player_index)
	var weapons = RunData.get_player_weapons(player_index)

	if weapons.size() < effects[Keys.weapon_slot_hash]:
		return RunData.add_weapon(weapons[randi() % weapons.size()], player_index)

	var upgrades = null
	for weapon in weapons:
		upgrades = weapon.upgrades_into
		if upgrades == null:
			continue
		
		RunData.remove_weapon(weapon, player_index)
		break

	if upgrades == null:
		return null

	return RunData.add_weapon(upgrades, player_index)


func spawm_effect_fengliu_structure(effect: Array, consumable: Node, player_index: int) -> void:
	var stat = Utils.get_stat(effect[0], player_index)
	var structure_count = effect[1] + int(stat / effect[2])
	for _index in range(structure_count):
		var pos = _entity_spawner.get_spawn_pos_in_area(consumable.global_position, 200)
		var queue = _entity_spawner.queues_to_spawn_structures[player_index]
		queue.push_back([EntityType.STRUCTURE, effect[3].scene, pos, effect[3]])


func get_box_cost(effect: Array) -> int:
    return int(effect[1] * (1.0 + (max(1, RunData.current_wave) - 1) * effect[2]))
		

func on_consumable_picked_up(consumable: Node, player_index: int) -> void :
	var effects = RunData.get_player_effect(effect_fengliu_picke_consumable_drop_structure, player_index)
	if effects.size() > 0:
		spawm_effect_fengliu_structure(effects[0], consumable, player_index)

	if consumable.consumable_data.my_id_hash != Keys.consumable_item_box_hash and consumable.consumable_data.my_id_hash != Keys.consumable_legendary_item_box_hash:
		.on_consumable_picked_up(consumable, player_index)
		return 

	effects = RunData.get_player_effect(effect_fengliu_auto_open_box, player_index)
	if effects.size() > 0:
		# 禁止 UI 显示
		consumable.consumable_data.to_be_processed_at_end_of_wave = false
		# 开箱
		var box_item_data = ItemService.process_item_box(consumable.consumable_data, RunData.current_wave, player_index)
		
		# 概率删除箱子道具全部负面效果
		effects = RunData.get_player_effect(effect_fengliu_apply_item_not_add_all_debuff, player_index)
		if effects.size() > 0 and effects[0][1] and Utils.get_chance_success(effects[0][0] / 100.0):
			var old_effects = box_item_data.effects.duplicate()
			var new_effects = box_item_data.effects.duplicate()
			RunData.remove_all_item_debuff_effects(new_effects)

			box_item_data.effects = new_effects
			RunData.add_item(box_item_data, player_index)
			box_item_data.effects = old_effects
		else:
			RunData.add_item(box_item_data, player_index)

	effects = RunData.get_player_effect(effect_fengliu_picked_box_cost_gold, player_index)
	if effects.size() == 0:
		.on_consumable_picked_up(consumable, player_index)
		return

	# 花费开箱
	var effect = effects[0]
	var cost_gold = get_box_cost(effect)

	if cost_gold > RunData.get_player_gold(player_index):
		consumable.consumable_data = ItemService.get_consumable_for_tier(Tier.COMMON)
		.on_consumable_picked_up(consumable, player_index)
		return

	RunData.remove_gold(cost_gold, player_index)
	if add_weapon(player_index) == null and effect[3] > 0:
		for _i in range(effect[3]):
			RunData.add_stat(RunData.get_random_primary_stats(), 1, player_index)

	.on_consumable_picked_up(consumable, player_index)


func fengliu_add_xp_gold_from_wave_time(effect: Array, player_index: int):
	var add_value = effect[1]
	if effect[0] != Keys.stat_levels_hash:
		add_value += RunData.get_stat(effect[0], player_index) * effect[2]
	else:
		add_value += RunData.get_player_level(player_index * effect[2])

	var gold = int(_wave_timer.time_left * add_value)
	RunData.add_gold(gold, player_index)
	RunData.add_xp(gold, player_index)


func clean_up_room():
	for player_index in RunData.get_player_count():
		var effects = RunData.get_player_effect(effect_fengliu_add_xp_gold_from_wave_time, player_index)
		if effects.size() > 0:
			fengliu_add_xp_gold_from_wave_time(effects[0], player_index)
	
	if not _end_wave_timer_timedout:
		.clean_up_room()