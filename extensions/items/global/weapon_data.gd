extends "res://items/global/weapon_data.gd"


var _fengliu_scene_actions_cache = null
var _fengliu_scene_actions_scene = null


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


# 武器效果文本：把场景 actions 数组里的动作翻译插到最前面
func get_effects_text(player_index: int, with_tracking_text: bool = true) -> String:
	var original_text: String = .get_effects_text(player_index, with_tracking_text)
	var action_text: String = _fengliu_get_action_effects_text(player_index)

	if action_text == "":
		return original_text

	if original_text == "":
		return action_text

	return action_text + "\n" + original_text


# 供炮塔动作桥接：读取武器场景 actions（公开包装）
func fengliu_get_actions() -> Array:
	return _fengliu_get_scene_actions()


func _fengliu_get_action_effects_text(player_index: int) -> String:
	var lines := []

	for action in _fengliu_get_scene_actions():
		if action == null or not is_instance_valid(action):
			continue

		var translation_key_value = action.get("action_name")
		if translation_key_value == null:
			continue

		var translation_key: String = str(translation_key_value)
		if translation_key == "":
			continue

		var args := []
		if action.has_method("get_args"):
			for value in action.get_args(player_index):
				args.push_back(str(value))

		var text: String = Text.text(translation_key.to_upper(), args)
		if text != "":
			lines.push_back(text)

	return PoolStringArray(lines).join("\n")


# 从武器场景根节点读取导出的 actions 数组；SceneState 不实例化场景
func _fengliu_get_scene_actions() -> Array:
	if _fengliu_scene_actions_scene == scene and _fengliu_scene_actions_cache != null:
		return _fengliu_scene_actions_cache

	_fengliu_scene_actions_scene = scene
	_fengliu_scene_actions_cache = []

	if scene == null:
		return _fengliu_scene_actions_cache

	var state = scene.get_state()
	if state == null:
		return _fengliu_scene_actions_cache

	for prop_index in state.get_node_property_count(0):
		if state.get_node_property_name(0, prop_index) != "actions":
			continue

		var value = state.get_node_property_value(0, prop_index)
		if value is Array:
			_fengliu_scene_actions_cache = value
		break

	return _fengliu_scene_actions_cache
