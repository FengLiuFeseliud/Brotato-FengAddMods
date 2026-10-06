extends "res://singletons/progress_data.gd"


const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_LINE_SPACE_DIR = "res://mods-unpacked/FengLiu-FengAddMods/zones/zone_line_space/"
const FENGLIU_LINE_SPACE_DLC_DATA_PATH = FENGLIU_LINE_SPACE_DIR + "line_space_dlc_data.tres"


var _fengliu_line_space_dlc_data: DLCData
var _fengliu_line_space_logged: bool = false


# 覆盖: 按原版 DLC 的做法把自己的 DLCData 交给 available_dlcs，
#   让原版 _ready() 里 `for available_dlc in available_dlcs: add_resources()` 去注册
func check_for_available_dlcs() -> void :
	.check_for_available_dlcs()

	if _fengliu_line_space_dlc_data == null:
		_fengliu_line_space_dlc_data = load(FENGLIU_LINE_SPACE_DLC_DATA_PATH) as DLCData

	# 资源缺失时列出断链再记错，避免出现「区域静默消失」这种难查的问题
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
	var zone_id: int = _fengliu_line_space_dlc_data.zones[0].my_id

	if not _fengliu_line_space_logged:
		_fengliu_line_space_logged = true
		var zones_info = []
		for zone in ZoneService.zones:
			zones_info.append("%s/my_id%d" % [zone.name, zone.my_id])
		ModLoaderLog.info("Line space zone ready: zone_id=%d zones=%d[%s] backgrounds=%d bosses=%d elites=%d (zone bosses=%d, zone elites=%d)" % [zone_id, ZoneService.zones.size(), ", ".join(zones_info), ItemService.backgrounds.size(), ItemService.bosses.size(), ItemService.elites.size(), ItemService.get_bosses_from_zone(zone_id).size(), ItemService.get_elites_from_zone(zone_id).size()], FENGLIU_MOD_ID)

		# 原版按下标取区域（下标必须等于 my_id），被挪位时给出告警便于排查
		var index: int = ZoneService.zones.find(_fengliu_line_space_dlc_data.zones[0])
		if index != zone_id:
			ModLoaderLog.warning("Line space zone index mismatch: index=%d my_id=%d" % [index, zone_id], FENGLIU_MOD_ID)

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

