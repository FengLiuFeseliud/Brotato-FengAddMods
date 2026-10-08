extends "res://singletons/progress_data.gd"


const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const FENGLIU_LINE_SPACE_DIR = "res://mods-unpacked/FengLiu-FengAddMods/zones/zone_line_space/"
const FENGLIU_LINE_SPACE_DLC_DATA_PATH = FENGLIU_LINE_SPACE_DIR + "line_space_dlc_data.tres"
const FENGLIU_LINE_SPACE_BACKGROUND_NAME = "BG_LINE_SPACE"


var _fengliu_line_space_dlc_data: DLCData
var _fengliu_line_space_logged: bool = false
var _fengliu_zone_own_backgrounds: Dictionary = {}



func check_for_available_dlcs() -> void :
	.check_for_available_dlcs()

	if _fengliu_line_space_dlc_data == null:
		_fengliu_line_space_dlc_data = load(FENGLIU_LINE_SPACE_DLC_DATA_PATH) as DLCData


	if _fengliu_line_space_dlc_data == null:
		_fengliu_log_missing_resources(FENGLIU_LINE_SPACE_DLC_DATA_PATH)
		ModLoaderLog.error("Failed to load line space dlc data: %s" % FENGLIU_LINE_SPACE_DLC_DATA_PATH, FENGLIU_MOD_ID)
		return

	# 幂等：read_all_dlcs() 等流程会清空重扫，缺了再补
	if not available_dlcs.has(_fengliu_line_space_dlc_data):
		available_dlcs.append(_fengliu_line_space_dlc_data)

	_fengliu_dedupe_available_dlcs()


# 覆盖: 原版读档之后，为各角色补齐本区域的难度条目（老存档里没有新区域的条目，难度会只剩最低档）
func load_game_file(try_fallback: = true) -> void :
	# 原版读档（含按存档状态增删 DLC 资源）
	.load_game_file(try_fallback)

	# 区域已注册后再补各角色的难度条目（首次读档发生在注册之前）
	if _fengliu_line_space_dlc_data != null and _fengliu_line_space_dlc_data.zones.size() > 0:
		_fengliu_ensure_line_space_zone_progress()

	# 原版按下标取区域：部分 mod 在本函数之后才追加自己的区域，故再延期自愈一次
	call_deferred("fengliu_ensure_line_space_zone_last", "deferred after load game file")


# 加载失败时递归列出断链（区域数据 → 波次 → 组 → 单位 → 场景 这类多层引用也能定位到具体文件）
func _fengliu_log_missing_resources(path: String, depth: int = 0) -> void :
	if depth > 4:
		return

	var file: = File.new()
	if file.open(path, File.READ) != OK:
		return

	# 只挑 ext_resource 行里的资源路径
	var refs: = []
	while not file.eof_reached():
		var line: String = file.get_line()
		if not line.begins_with("[ext_resource"):
			continue

		var start: int = line.find("path=\"")
		if start < 0:
			continue

		var ref_start: int = start + 6
		var ref_end: int = line.find("\"", ref_start)
		if ref_end < 0:
			continue

		refs.push_back(line.substr(ref_start, ref_end - ref_start))

	file.close()

	for ref in refs:
		if not ResourceLoader.exists(ref):
			ModLoaderLog.error("Missing resource: %s (referenced by %s)" % [ref, path], FENGLIU_MOD_ID)
		elif ref.ends_with(".tres") or ref.ends_with(".tscn"):
			_fengliu_log_missing_resources(ref, depth + 1)


# 原版按目录逐条收集 DLC，本环境曾把同一目录列举两次 ⇒ available_dlcs 里出现同一个实例两份
func _fengliu_dedupe_available_dlcs() -> void :
	var removed: int = 0

	# 倒序遍历、只保留首次出现，避免打乱既有顺序（第 0 项仍应是原版「深渊」）
	for i in range(available_dlcs.size() - 1, -1, -1):
		if available_dlcs.find(available_dlcs[i]) != i:
			available_dlcs.remove(i)
			removed += 1

	if removed > 0:
		ModLoaderLog.warning("Removed %d duplicated DLC data entries from available_dlcs." % removed, FENGLIU_MOD_ID)


# 补齐各角色在该区域的难度条目，并让新区域继承玩家已达成的最高可选难度
func _fengliu_ensure_line_space_zone_progress() -> void :
	# 先做一次区域下标自愈，保证下面读到的 my_id 就是最终值
	fengliu_ensure_line_space_zone_last("ensure progress")

	# 再把本区域的默认背景收窄（NCL 会把依赖方的背景塞进所有区域）
	_fengliu_enforce_line_space_own_backgrounds()

	var zone_id: int = _fengliu_line_space_dlc_data.zones[0].my_id

	if not _fengliu_line_space_logged:
		_fengliu_line_space_logged = true
		_fengliu_log_zone_state(zone_id)

	for character in ItemService.characters:
		if character == null:
			continue

		character._generate_hashes()

		var character_difficulty_info = null
		for difficulty_info in difficulties_unlocked:
			if difficulty_info.character_id_hash == character.my_id_hash:
				character_difficulty_info = difficulty_info
				break

		if character_difficulty_info == null:
			continue

		# 幂等：该角色已有本区域条目就跳过
		var already_has_zone: bool = false
		for zone_difficulty_info in character_difficulty_info.zones_difficulty_info:
			if zone_difficulty_info.zone_id == zone_id:
				already_has_zone = true
				break

		if not already_has_zone:
			character_difficulty_info.zones_difficulty_info.push_back(ZoneDifficultyInfo.new(zone_id))

	set_max_selectable_difficulty()


# 原版按下标取区域
func fengliu_ensure_line_space_zone_last(reason: String = "") -> void :
	if _fengliu_line_space_dlc_data == null:
		return
	if _fengliu_line_space_dlc_data.zones.size() == 0:
		return

	var zone = _fengliu_line_space_dlc_data.zones[0]
	var our_index: int = ZoneService.zones.find(zone)

	if our_index < 0:
		return

	# 本区域的默认背景收窄（幂等）：NCL 会把依赖方的背景追加进所有区域的 default_backgrounds
	_fengliu_enforce_line_space_own_backgrounds()

	fengliu_restore_zone_own_backgrounds("zone heal")

	if zone.my_id != our_index:
		zone.my_id = our_index
		_fengliu_apply_zone_id(our_index)

	var before: int = _fengliu_zone_mismatch_count()

	var simulated: Array = ZoneService.zones.duplicate()
	simulated.remove(our_index)
	simulated.push_back(zone)
	var after: int = _fengliu_zone_mismatch_count(simulated, zone, simulated.size() - 1)

	if after >= before:
		if before > 0:
			ModLoaderLog.warning("Line space zone stayed at index %d: mismatch kept at %d (moving would make it %d), reason=%s" % [our_index, before, after, reason], FENGLIU_MOD_ID)
		return

	var run_was_in_our_zone: bool = RunData.current_zone == our_index
	var selection_was_our_zone: bool = settings != null and settings.zone_selected == our_index
	var zones_before: String = _fengliu_zone_list_text()

	ZoneService.zones.remove(our_index)
	ZoneService.zones.push_back(zone)

	zone.my_id = ZoneService.zones.size() - 1
	_fengliu_apply_zone_id(zone.my_id)

	if run_was_in_our_zone:
		RunData.current_zone = zone.my_id

	if selection_was_our_zone:
		settings.zone_selected = zone.my_id

	_fengliu_migrate_zone_difficulty_info(our_index, zone.my_id)

	ModLoaderLog.info("Line space zone moved to the end: index %d -> %d (mismatch %d -> %d, run_zone_repointed=%s, selection_repointed=%s, reason=%s) before=[%s] after=[%s]" % [our_index, zone.my_id, before, after, str(run_was_in_our_zone), str(selection_was_our_zone), reason, zones_before, _fengliu_zone_list_text()], FENGLIU_MOD_ID)


func _fengliu_zone_mismatch_count(p_zones: Array = [], p_override_zone = null, p_override_id: int = -1) -> int :
	var zones_to_check: Array = ZoneService.zones if p_zones.size() == 0 else p_zones
	var count: int = 0

	for index in range(zones_to_check.size()):
		var zone = zones_to_check[index]
		if zone == null:
			continue

		var zone_id: int = p_override_id if zone == p_override_zone else zone.my_id
		if zone_id != index:
			count += 1

	return count


# 本区域 my_id 变化后，同步本区域 boss/精英的归属（原版 get_bosses_from_zone 按 zone_id 字段过滤）
func _fengliu_apply_zone_id(p_zone_id: int) -> void :
	for boss in _fengliu_line_space_dlc_data.bosses:
		if boss != null:
			boss.zone_id = p_zone_id

	for elite in _fengliu_line_space_dlc_data.elites:
		if elite != null:
			elite.zone_id = p_zone_id


# 把老存档里挂在本区域旧下标上的难度条目按值复制到新下标（serialize → 取最大合并）
func _fengliu_migrate_zone_difficulty_info(p_old_id: int, p_new_id: int) -> void :
	if p_old_id < 0 or p_old_id == p_new_id:
		return

	for difficulty_info in difficulties_unlocked:
		if difficulty_info == null:
			continue

		var source: ZoneDifficultyInfo = null
		var target: ZoneDifficultyInfo = null

		# 注意：同一角色下可能同时存在旧下标与别人共用下标的条目，这里只取第一条作为来源
		for zone_difficulty_info in difficulty_info.zones_difficulty_info:
			if zone_difficulty_info.zone_id == p_old_id and source == null:
				source = zone_difficulty_info
			elif zone_difficulty_info.zone_id == p_new_id:
				target = zone_difficulty_info

		if source == null:
			continue

		var payload: Dictionary = source.serialize()
		payload["zone_id"] = p_new_id

		if target == null:
			target = ZoneDifficultyInfo.new(p_new_id)
			difficulty_info.zones_difficulty_info.push_back(target)

		target.deserialize_and_merge_take_max(payload)


# 该背景是不是本 mod 自己的（按资源路径 / 背景名判定）
func _fengliu_is_own_background(background) -> bool:
	if background == null:
		return false

	if str(background.resource_path).begins_with(FENGLIU_MOD_DIR):
		return true

	return str(background.name) == FENGLIU_LINE_SPACE_BACKGROUND_NAME


func _fengliu_enforce_line_space_own_backgrounds() -> void :
	if _fengliu_line_space_dlc_data == null or _fengliu_line_space_dlc_data.zones.size() == 0:
		return

	var zone = _fengliu_line_space_dlc_data.zones[0]
	if zone == null:
		return

	var backgrounds = zone.default_backgrounds
	if backgrounds == null:
		return

	var own_backgrounds: Array = []
	for background in backgrounds:
		if _fengliu_is_own_background(background):
			own_backgrounds.push_back(background)

	# 一张自己的都没有（异常数据）⇒ 不碰，避免把区域弄成"无背景"
	if own_backgrounds.size() == 0:
		return

	# 已经干净了 ⇒ 幂等返回
	if own_backgrounds.size() == backgrounds.size():
		return

	var kept_names: Array = []
	for background in own_backgrounds:
		kept_names.push_back(str(background.name))

	zone.default_backgrounds = own_backgrounds

	ModLoaderLog.info("Line space zone backgrounds narrowed: %d -> %d (kept=%s)" % [backgrounds.size(), own_backgrounds.size(), ", ".join(kept_names)], FENGLIU_MOD_ID)


# 本区域对象
func fengliu_get_line_space_zone():
	if _fengliu_line_space_dlc_data == null or _fengliu_line_space_dlc_data.zones.size() == 0:
		return null

	return _fengliu_line_space_dlc_data.zones[0]


func fengliu_resolve_zone(p_zone_id: int):
	for zone in ZoneService.zones:
		if zone != null and zone.my_id == p_zone_id:
			return zone

	if p_zone_id >= 0 and p_zone_id < ZoneService.zones.size():
		return ZoneService.zones[p_zone_id]

	return null


# 本区域自持的背景
func fengliu_get_line_space_own_background():
	var zone = fengliu_get_line_space_zone()
	if zone == null or zone.default_backgrounds == null:
		return null

	for background in zone.default_backgrounds:
		if _fengliu_is_own_background(background):
			return background

	return null


func _fengliu_get_zone_own_backgrounds(zone) -> Array:
	var path: String = str(zone.resource_path)
	if path == "":
		return []

	if _fengliu_zone_own_backgrounds.has(path):
		return _fengliu_zone_own_backgrounds[path]

	var own: Array = []
	var pristine = ResourceLoader.load(path, "", true)

	if pristine != null and pristine.default_backgrounds != null:
		for background in pristine.default_backgrounds:
			own.push_back(background)

	_fengliu_zone_own_backgrounds[path] = own

	return own


func fengliu_restore_zone_own_backgrounds(reason: String = "") -> void :
	var restored: Array = []

	for zone in ZoneService.zones:
		if zone == null or zone.default_backgrounds == null:
			continue

		var own: Array = _fengliu_get_zone_own_backgrounds(zone)
		if own.size() == 0:
			continue

		var current: Array = zone.default_backgrounds
		if current.size() == own.size():
			var same: bool = true
			for index in range(own.size()):
				if current[index] != own[index]:
					same = false
					break
			if same:
				continue

		var dropped: Array = []
		for background in current:
			if not own.has(background):
				dropped.push_back(str(background.name) if background != null else "<null>")

		zone.default_backgrounds = own.duplicate()
		restored.push_back("%s %d->%d%s" % [str(zone.name), current.size(), own.size(), (" dropped=" + ", ".join(dropped)) if dropped.size() > 0 else ""])

	if restored.size() > 0:
		ModLoaderLog.info("Zone backgrounds restored (%s): %s" % [reason, "; ".join(restored)], FENGLIU_MOD_ID)


# 区域列表 + 下标/my_id 的一行文本（日志用）
func _fengliu_zone_list_text() -> String:
	var zones_info = []
	for index in range(ZoneService.zones.size()):
		zones_info.append("%d:%s/my_id%d" % [index, ZoneService.zones[index].name, ZoneService.zones[index].my_id])

	return ", ".join(zones_info)


# 一次性 info 日志：区域列表 + 下标/my_id 一致性（便于日后定位「谁顶了谁」）
func _fengliu_log_zone_state(p_zone_id: int) -> void :
	var zones_info = []
	for zone in ZoneService.zones:
		zones_info.append("%s/my_id%d" % [zone.name, zone.my_id])
	ModLoaderLog.info("Line space zone ready: zone_id=%d zones=%d[%s] backgrounds=%d bosses=%d elites=%d (zone bosses=%d, zone elites=%d)" % [p_zone_id, ZoneService.zones.size(), ", ".join(zones_info), ItemService.backgrounds.size(), ItemService.bosses.size(), ItemService.elites.size(), ItemService.get_bosses_from_zone(p_zone_id).size(), ItemService.get_elites_from_zone(p_zone_id).size()], FENGLIU_MOD_ID)

	var mismatch: int = _fengliu_zone_mismatch_count()
	if mismatch != 0:
		ModLoaderLog.warning("Zone id mismatch remains: %d zone(s) have my_id != index (a third-party mod may hardcode its my_id)" % mismatch, FENGLIU_MOD_ID)

