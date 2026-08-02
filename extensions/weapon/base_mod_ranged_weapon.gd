extends RangedWeapon


var effect_gain_random_killed_stat = Keys.generate_hash("effect_gain_random_killed_stat")


static func get_dynamic_value(stat_min_value: int, stat_max_value: int, stat_no_zero: bool) -> int:
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	if dynamic_value == 0 and stat_no_zero:
		return get_dynamic_value(stat_min_value, stat_max_value, stat_no_zero)
	return dynamic_value


func on_killed_something(_thing_killed: Node, hitbox: Hitbox) -> void :
	.on_killed_something(_thing_killed, hitbox)
	for effect in effects:
		if effect.key_hash == effect_gain_random_killed_stat and _enemies_killed_this_wave_count % effect.value == 0:
			var random_val = get_dynamic_value(effect.stat_min_value, effect.stat_max_value, effect.stat_no_zero)
			RunData.add_stat(effect.stat_hash, random_val, player_index)
			emit_signal("tracked_value_updated", random_val)

