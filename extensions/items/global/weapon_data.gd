extends "res://items/global/weapon_data.gd"


# 通用进化缩放 key：任意武器/效果只要 stats.scaling_stats 含此 key 就按进化符号显示
func get_weapon_stats_text(player_index: int, hide_if_non_unlock_in_codex: bool = false) -> String:
	if stats == null or not _has_fengliu_evolution_scaling():
		return .get_weapon_stats_text(player_index, hide_if_non_unlock_in_codex)

	if player_index < 0:
		return .get_weapon_stats_text(player_index, hide_if_non_unlock_in_codex)

	var original_scaling_stats = stats.scaling_stats if stats.scaling_stats != null else []
	var evolution: float = Utils.get_stat(Keys.stat_evolution_hash, player_index)
	var new_scaling_stats: = []

	for entry in original_scaling_stats:
		if not (entry is Array) or entry.size() < 2:
			continue

		if _is_fengliu_evolution_entry(entry):
			var magnitude: float = abs(float(entry[1]))

			if evolution < 0.0:
				new_scaling_stats.append([entry[0], - magnitude])
			elif evolution > 0.0:
				new_scaling_stats.append([entry[0], magnitude])
			else:
				new_scaling_stats.append([entry[0], magnitude])
				new_scaling_stats.append([entry[0], - magnitude])
		else:
			new_scaling_stats.append([entry[0], entry[1]])

	stats.scaling_stats = new_scaling_stats
	var text: String = .get_weapon_stats_text(player_index, hide_if_non_unlock_in_codex)
	stats.scaling_stats = original_scaling_stats
	return text


func _has_fengliu_evolution_scaling() -> bool:
	if stats == null or stats.scaling_stats == null:
		return false

	for entry in stats.scaling_stats:
		if _is_fengliu_evolution_entry(entry):
			return true

	return false


func _is_fengliu_evolution_entry(entry) -> bool:
	if not (entry is Array) or entry.size() < 2:
		return false

	var entry_key = entry[0]
	if entry_key is String:
		entry_key = Keys.generate_hash(entry_key)

	return Utils.is_fengliu_evolution_scaling_key(entry_key)
