extends Node

const BLOCK_SIZE = 10

var events: Dictionary = {}
var _icon_cache: Dictionary = {}
var _run_counts: Dictionary = {}
var _scheduled_blocks: Dictionary = {}
var _counts_initialized: bool = false


func register_event(data) -> void:
	if data == null:
		return

	var id_value = data.get("id")
	if id_value == null:
		ModLoaderLog.warning("Zone event has no id, skipped", "FengAddMods")
		return

	var event_id = String(id_value)
	if event_id == "":
		ModLoaderLog.warning("Zone event has empty id, skipped", "FengAddMods")
		return

	if events.has(event_id):
		ModLoaderLog.warning(
			"Zone event id already registered, overwriting: %s" % event_id,
			"FengAddMods"
		)

	events[event_id] = data
	ModLoaderLog.info("Zone event registered: %s" % event_id, "FengAddMods")


func load_events_from_dir(dir_path: String) -> void:
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		ModLoaderLog.error("Failed to open zone events directory: %s" % dir_path, "FengAddMods")
		return

	dir.list_dir_begin(true, true)
	var file_name := dir.get_next()
	while file_name != "":
		var full_path = dir_path.plus_file(file_name)
		var is_dir = dir.current_is_dir()

		if is_dir:
			load_events_from_dir(full_path)
		elif file_name.get_extension() == "tres":
			var data = load(full_path)
			if data != null:
				register_event(data)
			else:
				ModLoaderLog.error("Failed to load zone event: %s" % full_path, "FengAddMods")

		file_name = dir.get_next()
	dir.list_dir_end()


func get_event(event_id: String):
	return events.get(event_id)


func get_event_icon(data):
	if data == null:
		return null

	var assigned_icon = data.get("icon")
	if assigned_icon != null:
		return assigned_icon

	var icon_path_value = data.get("icon_path")
	var icon_path = "" if icon_path_value == null else String(icon_path_value)
	if icon_path == "":
		return null

	var id_value = data.get("id")
	var event_id = "" if id_value == null else String(id_value)
	if _icon_cache.has(event_id):
		return _icon_cache[event_id]

	var texture = Utils.brotils_create_texture_from_image_path(icon_path)
	if texture == null:
		_icon_cache[event_id] = null
		ModLoaderLog.error("Zone event icon not found: %s -> %s" % [event_id, icon_path], "FengAddMods")
		return null

	_icon_cache[event_id] = texture
	ModLoaderLog.info("Zone event icon loaded once: %s -> %s" % [event_id, icon_path], "FengAddMods")
	return texture


func get_events_for_wave(zone, wave_number: int, difficulty: int) -> Array:
	var result = []
	if zone == null:
		return result

	var zone_name = String(zone.name)

	for event_id in events:
		var data = events[event_id]
		if data == null:
			continue

		var enabled_value = data.get("enabled")
		if enabled_value != null and not bool(enabled_value):
			continue

		var event_zone_names = data.get("zone_names")
		if event_zone_names != null and event_zone_names.size() > 0:
			if not event_zone_names.has(zone_name):
				continue

		if wave_number < int(data.get("min_wave")) or wave_number > int(data.get("max_wave")):
			continue
		if difficulty < int(data.get("min_difficulty")) or difficulty > int(data.get("max_difficulty")):
			continue

		result.push_back(data)

	return result


# 难度选择面板用：取该区域/难度下所有自定义事件的说明与图标
func get_descriptions_for_difficulty(zone, difficulty: int) -> Array:
	var entries = []
	if zone == null:
		return entries

	var zone_name = String(zone.name)
	var seen = {}

	for event_id in events:
		var data = events[event_id]
		if data == null:
			continue

		var enabled_value = data.get("enabled")
		if enabled_value != null and not bool(enabled_value):
			continue

		var event_zone_names = data.get("zone_names")
		if event_zone_names != null and event_zone_names.size() > 0:
			if not event_zone_names.has(zone_name):
				continue

		if difficulty < int(data.get("min_difficulty")) or difficulty > int(data.get("max_difficulty")):
			continue

		var text_key_value = data.get("text_key")
		var text_key = "" if text_key_value == null else String(text_key_value)
		if text_key == "" or seen.has(text_key):
			continue

		var text = Text.text(text_key)
		if text == text_key:
			ModLoaderLog.warning("Zone event translation missing: %s" % text_key, "FengAddMods")
			continue

		seen[text_key] = true
		entries.push_back({
			"text": text,
			"icon": get_event_icon(data),
			"priority": int(data.get("priority")),
		})

	entries.sort_custom(self, "_sort_icon_entries")
	return entries


func get_texts_for_difficulty(zone, difficulty: int) -> Array:
	var texts = []
	for entry in get_descriptions_for_difficulty(zone, difficulty):
		texts.push_back(String(entry.get("text")))
	return texts


func schedule_events_for_base_wave(zone, base_wave: int, difficulty: int) -> void:
	if zone == null:
		return

	if not _counts_initialized:
		_init_run_counts_from_spawn()
		_counts_initialized = true

	var safe_base_wave = max(1, base_wave)
	var block_start = int((safe_base_wave - 1) / BLOCK_SIZE) * BLOCK_SIZE + 1
	_schedule_block(zone, block_start, block_start + BLOCK_SIZE - 1, difficulty)
	_schedule_block(zone, block_start + BLOCK_SIZE, block_start + BLOCK_SIZE * 2 - 1, difficulty)


func _schedule_block(zone, from_wave: int, to_wave: int, difficulty: int) -> void:
	if zone == null:
		return

	var block_key = from_wave
	if _scheduled_blocks.has(block_key):
		return

	# 读档/旧存档中已有本区块的注册事件时，保持原样，不重抽
	if _has_registered_event_in_range(from_wave, to_wave):
		_scheduled_blocks[block_key] = true
		return

	# 区域/难度尚未确定时可能没有任何可排期事件；
	# 此时不要标记区块，等后续 init_events_nightmare 再补排。
	if not _has_eligible_event_in_range(zone, from_wave, to_wave, difficulty):
		ModLoaderLog.info(
			"Zone event block %d-%d deferred: no eligible events (zone=%s)" %
			[from_wave, to_wave, String(zone.name)],
			"FengAddMods"
		)
		return

	_scheduled_blocks[block_key] = true

	for wave_number in range(from_wave, to_wave + 1):
		_schedule_wave(zone, wave_number, difficulty)

	for event_id in events:
		_ensure_min_per_block(zone, from_wave, to_wave, difficulty, String(event_id))

	var scheduled = {}
	for entry in RunData.events_spawn:
		var wave_number = int(entry[0])
		if wave_number < from_wave or wave_number > to_wave:
			continue
		var event_id = String(entry[1])
		if get_event(event_id) == null:
			continue
		if not scheduled.has(event_id):
			scheduled[event_id] = []
		scheduled[event_id].push_back(wave_number)

	ModLoaderLog.info(
		"Zone event block %d-%d: %s" % [from_wave, to_wave, str(scheduled)],
		"FengAddMods"
	)


func _schedule_wave(zone, wave_number: int, difficulty: int) -> void:
	if _has_registered_event_in_spawn(wave_number):
		return

	for data in get_events_for_wave(zone, wave_number, difficulty):
		_try_schedule_event(data, wave_number)


func _try_schedule_event(data, wave_number: int) -> void:
	var id_value = data.get("id")
	var event_id = "" if id_value == null else String(id_value)
	if event_id == "":
		return

	var count = int(_run_counts.get(event_id, 0))
	if bool(data.get("once_per_run")) and count > 0:
		return

	var max_per_run = int(data.get("max_per_run"))
	if max_per_run > 0 and count >= max_per_run:
		return

	var chance = 0.0
	var chance_value = data.get("chance_per_wave")
	if chance_value != null:
		chance = float(chance_value)

	if not Utils.get_chance_success(chance):
		return

	if not _has_event_in_spawn(wave_number, event_id):
		RunData.events_spawn.push_back([wave_number, event_id])

	_run_counts[event_id] = count + 1
	ModLoaderLog.info(
		"Zone event scheduled: wave %d -> %s" % [wave_number, event_id],
		"FengAddMods"
	)


func _ensure_min_per_block(
	zone,
	from_wave: int,
	to_wave: int,
	difficulty: int,
	event_id: String
) -> void:
	var data = get_event(event_id)
	if data == null:
		return

	var min_count = int(data.get("min_per_block"))
	if min_count <= 0:
		return

	var current_count = _count_event_in_range(event_id, from_wave, to_wave)
	if current_count >= min_count:
		return

	var candidates = []
	for wave_number in range(from_wave, to_wave + 1):
		if _has_event_in_spawn(wave_number, event_id):
			continue
		if _has_registered_event_in_spawn(wave_number):
			continue
		if not get_events_for_wave(zone, wave_number, difficulty).has(data):
			continue
		candidates.push_back(wave_number)

	while current_count < min_count and candidates.size() > 0:
		var index = Utils.randi_range(0, candidates.size() - 1)
		var wave_number = candidates[index]
		candidates.remove(index)

		var count = int(_run_counts.get(event_id, 0))
		if bool(data.get("once_per_run")) and count > 0:
			break
		var max_per_run = int(data.get("max_per_run"))
		if max_per_run > 0 and count >= max_per_run:
			break

		RunData.events_spawn.push_back([wave_number, event_id])
		_run_counts[event_id] = count + 1
		current_count += 1
		ModLoaderLog.info(
			"Zone event fallback: block %d-%d -> wave %d -> %s" %
			[from_wave, to_wave, wave_number, event_id],
			"FengAddMods"
		)


func get_icons_for_wave(wave_number: int) -> Array:
	var result = []
	var seen := {}

	for entry in RunData.events_spawn:
		if int(entry[0]) != wave_number:
			continue

		var event_id = String(entry[1])
		if seen.has(event_id):
			continue

		var data = get_event(event_id)
		if data == null:
			continue

		var show_value = data.get("show_in_timeline")
		if show_value != null and not bool(show_value):
			continue

		var icon = get_event_icon(data)
		if icon == null:
			continue

		seen[event_id] = true
		result.push_back({
			"id": event_id,
			"icon": icon,
			"priority": int(data.get("priority")),
		})

	result.sort_custom(self, "_sort_icon_entries")
	return result


func _sort_icon_entries(a, b) -> bool:
	return int(a.get("priority", 0)) > int(b.get("priority", 0))


func _has_event_in_spawn(wave_number: int, event_id: String) -> bool:
	for entry in RunData.events_spawn:
		if int(entry[0]) == wave_number and String(entry[1]) == event_id:
			return true
	return false


func _has_registered_event_in_spawn(wave_number: int) -> bool:
	for entry in RunData.events_spawn:
		if int(entry[0]) == wave_number and get_event(String(entry[1])) != null:
			return true
	return false


func _has_registered_event_in_range(from_wave: int, to_wave: int) -> bool:
	for entry in RunData.events_spawn:
		var wave_number = int(entry[0])
		if wave_number < from_wave or wave_number > to_wave:
			continue
		if get_event(String(entry[1])) != null:
			return true
	return false


func _has_eligible_event_in_range(zone, from_wave: int, to_wave: int, difficulty: int) -> bool:
	for wave_number in range(from_wave, to_wave + 1):
		if get_events_for_wave(zone, wave_number, difficulty).size() > 0:
			return true
	return false


func _count_event_in_range(event_id: String, from_wave: int, to_wave: int) -> int:
	var count = 0
	for entry in RunData.events_spawn:
		var wave_number = int(entry[0])
		if wave_number < from_wave or wave_number > to_wave:
			continue
		if String(entry[1]) == event_id:
			count += 1
	return count


func _init_run_counts_from_spawn() -> void:
	for entry in RunData.events_spawn:
		var event_id = String(entry[1])
		if get_event(event_id) == null:
			continue
		_run_counts[event_id] = int(_run_counts.get(event_id, 0)) + 1


func reset_run_counts() -> void:
	_run_counts.clear()
	_scheduled_blocks.clear()
	_counts_initialized = false
