extends Weapon


var effect_gain_random_killed_stat = Keys.generate_hash("gain_random_killed_stat")
var effect_weapon_killed_loot = Keys.generate_hash("weapon_killed_loot")


var wave_gain = Keys.generate_hash("wave_gain")


static func get_dynamic_value(stat_min_value: int, stat_max_value: int, stat_no_zero: bool) -> int:
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	if dynamic_value == 0 and stat_no_zero:
		return get_dynamic_value(stat_min_value, stat_max_value, stat_no_zero)
	return dynamic_value


func gain_random_killed_stat(effect: NullEffect) -> void:
	if _enemies_killed_this_wave_count % effect.value != 0:
		return
	
	var random_val = get_dynamic_value(effect.stat_min_value, effect.stat_max_value, effect.stat_no_zero)
	RunData.add_stat(effect.stat_hash, random_val, player_index)
	emit_signal("tracked_value_updated", random_val)


func wave_gain(effect: NullEffect) -> int:
	var kill_count_value = effect.value + RunData.current_wave * effect.gain_value
	return int(effect.cap_value if kill_count_value > effect.cap_value else kill_count_value)


func spawn_consumable(spawn_pos: Vector2) -> void:
	var main = get_tree().current_scene

	var consumable = main.get_node_from_pool(main._consumable_pool_id, main._consumables_container)
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
	consumable.drop(spawn_pos, 0, push_back_destination)
	
	main._consumables.push_back(consumable)
	emit_signal("tracked_value_updated", 1)


func weapon_killed_loot(effect: NullEffect, spawn_pos: Vector2) -> void:
	var kill_count_value = wave_gain(effect)
	if _enemies_killed_this_wave_count % kill_count_value != 0:
		return

	spawn_consumable(spawn_pos)


func on_killed_something(_thing_killed: Node, hitbox: Hitbox) -> void :
	.on_killed_something(_thing_killed, hitbox)

	for effect in effects:
		if effect.custom_key_hash == effect_gain_random_killed_stat:
			gain_random_killed_stat(effect)

		if effect.custom_key_hash == effect_weapon_killed_loot:
			weapon_killed_loot(effect, _thing_killed.global_position)

