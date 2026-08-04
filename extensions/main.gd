extends Main

var effect_can_add_chance_stat_damage_when_pickup_gold = Keys.generate_hash("effect_can_add_chance_stat_damage_when_pickup_gold")
var effect_can_add_chance_stat_damage_when_death = Keys.generate_hash("effect_can_add_chance_stat_damage_when_death")
var effect_random_stats_on_level_up = Keys.generate_hash("effect_random_stats_on_level_up")
var effect_picked_box_cost_gold = Keys.generate_hash("picke_box_cost_gold")
var effect_picke_consumable_drop_structure = Keys.generate_hash("picke_consumable_drop_structure")


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
		
	var effects = RunData.get_player_effect(effect_can_add_chance_stat_damage_when_pickup_gold, player_index)
	if effects.size() == 0:
		.on_gold_picked_up(gold, player_index)
		return
	
	effects[0] = get_dynamic_chance_to_effect(effects[0], player_index)
	handle_stat_damages(effects, player_index)
	.on_gold_picked_up(gold, player_index)


func _on_enemy_died(enemy: Enemy, args: Entity.DieArgs) -> void:
	if _cleaning_up and args.enemy_killed_by_player or enemy is Boss:
		._on_enemy_died(enemy, args)
		return
	
	for player in _get_shuffled_live_players():
		var player_index = player.player_index
		var effects = RunData.get_player_effect(effect_can_add_chance_stat_damage_when_death, player_index)
		if effects.size() > 0:
			effects[0] = get_dynamic_chance_to_effect(effects[0], player_index)
			handle_stat_damages(effects, player_index)
				
	._on_enemy_died(enemy, args)


func on_levelled_up(player_index: int) -> void :
	.on_levelled_up(player_index)
	
	var effects = RunData.get_player_effect(effect_random_stats_on_level_up, player_index)
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


func spawm_effect_structure(effect: Array, consumable: Node, player_index: int) -> void:
	var stat = Utils.get_stat(effect[0], player_index)
	var structure_count = effect[1] + int(stat / effect[2])
	for _index in range(structure_count):
		var pos = _entity_spawner.get_spawn_pos_in_area(consumable.global_position, 200)
		var queue = _entity_spawner.queues_to_spawn_structures[player_index]
		queue.push_back([EntityType.STRUCTURE, effect[3].scene, pos, effect[3]])
		

func on_consumable_picked_up(consumable: Node, player_index: int) -> void :
	var effects = RunData.get_player_effect(effect_picke_consumable_drop_structure, player_index)
	if effects.size() > 0:
		spawm_effect_structure(effects[0], consumable, player_index)

	if consumable.consumable_data.my_id_hash != Keys.consumable_item_box_hash and consumable.consumable_data.my_id_hash != Keys.consumable_legendary_item_box_hash:
		.on_consumable_picked_up(consumable, player_index)
		return 

	effects = RunData.get_player_effect(effect_picked_box_cost_gold, player_index)
	if effects.size() == 0:
		.on_consumable_picked_up(consumable, player_index)
		return

	var effect = effects[0]
	var gold = RunData.get_player_gold(player_index)
	var cost_gold = effect[1] + int(gold * (effect[2] / 100.0))

	if cost_gold > gold:
		consumable.consumable_data = ItemService.get_consumable_for_tier(Tier.COMMON)
		.on_consumable_picked_up(consumable, player_index)
		return

	RunData.remove_gold(cost_gold, player_index)
	if add_weapon(player_index) == null and effect[3] > 0:
		for _i in range(effect[3]):
			RunData.add_stat(RunData.get_random_primary_stats(), 1, player_index)

	.on_consumable_picked_up(consumable, player_index)