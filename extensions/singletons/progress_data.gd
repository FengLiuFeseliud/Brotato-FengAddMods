extends "res://singletons/progress_data.gd"

# 1.2.0 区域集成：zone_service.gd 负责按稳定 my_id 注册 ZoneData，
# 这里负责解锁、每个角色的难度条目与背景收敛。


const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const FENGLIU_LINE_SPACE_ZONE_PATH = FENGLIU_MOD_DIR + "zones/zone_line_space/zone_line_space_data.tres"
const FENGLIU_LINE_SPACE_BACKGROUND_NAME = "BG_LINE_SPACE"
# 稳定 id：与 .tres / boss / elite 的 my_id 一致，禁止按数组下标改写（参考 NCL）
const FENGLIU_LINE_SPACE_ZONE_ID: int = 3


var _fengliu_line_space_zone = null
var _fengliu_line_space_logged: bool = false
var _fengliu_zone_own_backgrounds: Dictionary = {}


# 扩展存档：把波次强度统计附加到 run_state。
func get_run_state(
	shop_items: = [],
	reroll_count: = [],
	paid_reroll_count: = [],
	initial_free_rerolls: = [],
	free_rerolls: = [],
	item_steals: = []
) -> Dictionary:
	var run_state = .get_run_state(shop_items, reroll_count, paid_reroll_count, initial_free_rerolls, free_rerolls, item_steals)
	# 仅在进行中的对局附加，普通存档保持干净
	if run_state.get("has_run_state", false):
		RunData.fengliu_write_wave_intensity_state(run_state)
	return run_state


# 覆盖: 原版在这里按 ZoneService.zones 解锁区域 / 建难度条目；
# ZoneService 的 _ready 晚于 ProgressData，原点看不到追加的区域，故补一次。
func add_unlocked_by_default() -> void :
	.add_unlocked_by_default()
	_fengliu_ensure_line_space_zone_progress()


# 覆盖: 读档之后补一次（老存档里没有本区域的难度条目）
func load_game_file(try_fallback: = true) -> void :
	.load_game_file(try_fallback)
	_fengliu_ensure_line_space_zone_progress()
	call_deferred("_fengliu_ensure_line_space_zone_progress")


# 覆盖: 调试全解锁时同样要带上本区域
func unlock_all() -> void :
	.unlock_all()
	_fengliu_ensure_line_space_zone_progress()


# 幂等：保证区域已入列、my_id/归属正确、已解锁、每个角色都有难度条目、背景收敛
func _fengliu_ensure_line_space_zone_progress() -> void :
	# 先确保区域仍在 ZoneService.zones 里（NCL 过滤 / 其它 mod 重建数组后仍然在位）
	if ZoneService.has_method("fengliu_ensure_line_space_zone_registered"):
		ZoneService.call("fengliu_ensure_line_space_zone_registered")

	var zone = fengliu_get_line_space_zone()
	if zone == null:
		return

	if ZoneService.zones == null:
		return

	var zone_id: int = int(zone.my_id)
	_fengliu_apply_zone_id(zone_id)

	# NCL 类 mod 会把依赖方背景塞进所有区域；本区域只保留自己的背景
	_fengliu_enforce_line_space_own_backgrounds()

	if zone.unlocked_by_default and not zones_unlocked.has(zone_id):
		zones_unlocked.push_back(zone_id)

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

		var already_has_zone: bool = false
		for zone_difficulty_info in character_difficulty_info.zones_difficulty_info:
			if zone_difficulty_info.zone_id == zone_id:
				already_has_zone = true
				break

		if not already_has_zone:
			character_difficulty_info.zones_difficulty_info.push_back(ZoneDifficultyInfo.new(zone_id))

	set_max_selectable_difficulty()


# 本区域对象（替代旧版的 dlc_data.zones[0]）：优先用 ZoneService 里已注册的实例
func fengliu_get_line_space_zone():
	if ZoneService.has_method("fengliu_get_line_space_zone"):
		var zone = ZoneService.call("fengliu_get_line_space_zone")
		if zone != null:
			_fengliu_line_space_zone = zone
			return zone

	if ZoneService.has_method("fengliu_ensure_line_space_zone_registered"):
		var registered_zone = ZoneService.call("fengliu_ensure_line_space_zone_registered")
		if registered_zone != null:
			_fengliu_line_space_zone = registered_zone
			return registered_zone

	# 兼容：ZoneService 扩展不可用时退回直接加载（仍保持固定 id）
	if _fengliu_line_space_zone == null:
		_fengliu_line_space_zone = load(FENGLIU_LINE_SPACE_ZONE_PATH)

	if _fengliu_line_space_zone != null:
		_fengliu_line_space_zone.my_id = FENGLIU_LINE_SPACE_ZONE_ID

	return _fengliu_line_space_zone


# 同步本区域 boss/精英的归属（1.2.0 按 zone_id 过滤）
func _fengliu_apply_zone_id(p_zone_id: int) -> void :
	var zone = fengliu_get_line_space_zone()
	if zone == null:
		return

	for boss in zone.bosses:
		if boss != null:
			boss.zone_id = p_zone_id

	for elite in zone.elites:
		if elite != null:
			elite.zone_id = p_zone_id


# 兼容旧调用点：区域 id 已固定，这里只补一次区域进度（不再移动数组 / 改写 my_id）
func fengliu_ensure_line_space_zone_last(_reason: String = "") -> void :
	_fengliu_ensure_line_space_zone_progress()


func _fengliu_is_own_background(background) -> bool:
	if background == null:
		return false

	if str(background.resource_path).begins_with(FENGLIU_MOD_DIR):
		return true

	return str(background.name) == FENGLIU_LINE_SPACE_BACKGROUND_NAME


# 本区域的 default_backgrounds 只保留自己的背景（其它 mod 可能往所有区域塞背景）
func _fengliu_enforce_line_space_own_backgrounds() -> void :
	var zone = fengliu_get_line_space_zone()
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

	if own_backgrounds.size() == backgrounds.size():
		return

	var kept_names: Array = []
	for background in own_backgrounds:
		kept_names.push_back(str(background.name))

	zone.default_backgrounds = own_backgrounds

	ModLoaderLog.info("Line space zone backgrounds narrowed: %d -> %d (kept=%s)" % [backgrounds.size(), own_backgrounds.size(), ", ".join(kept_names)], FENGLIU_MOD_ID)


func fengliu_resolve_zone(p_zone_id: int):
	for zone in ZoneService.zones:
		if zone != null and int(zone.my_id) == p_zone_id:
			return zone

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


# 把所有区域被第三方注入的背景还原为各自 .tres 里声明的列表
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


# 一次性 info 日志：区域列表（index:name/my_id）+ 重复 id 诊断（NCL 风格）
func _fengliu_log_zone_state(p_zone_id: int) -> void :
	var zones_info = []
	var seen_ids: Dictionary = {}
	var duplicates: Array = []

	for index in range(ZoneService.zones.size()):
		var zone = ZoneService.zones[index]
		if zone == null:
			continue

		var zone_id: int = int(zone.my_id)
		zones_info.append("%d:%s/my_id%d" % [index, str(zone.name), zone_id])
		if seen_ids.has(zone_id):
			duplicates.push_back(str(zone_id))
		else:
			seen_ids[zone_id] = true

	var own_zone = fengliu_get_line_space_zone()
	var own_bosses: int = own_zone.bosses.size() if own_zone != null else 0
	var own_elites: int = own_zone.elites.size() if own_zone != null else 0
	var global_bosses: int = ZoneService.bosses.size() if ZoneService.bosses != null else 0

	ModLoaderLog.info("Line space zone ready: zone_id=%d zones=%d[%s] backgrounds=%d global_bosses=%d (zone bosses=%d, zone elites=%d)" % [p_zone_id, ZoneService.zones.size(), ", ".join(zones_info), ItemService.backgrounds.size(), global_bosses, own_bosses, own_elites], FENGLIU_MOD_ID)

	if duplicates.size() > 0:
		ModLoaderLog.error("Duplicate zone my_id detected: %s" % ", ".join(duplicates), FENGLIU_MOD_ID)
