extends "res://singletons/progress_data.gd"

# 1.2.0 区域集成：zone_service.gd 负责把 ZoneData 追加进 ZoneService.zones，
# 这里负责解锁、每个角色的难度条目、背景收敛与下标自愈。


const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const FENGLIU_LINE_SPACE_ZONE_PATH = FENGLIU_MOD_DIR + "zones/zone_line_space/zone_line_space_data.tres"
const FENGLIU_LINE_SPACE_BACKGROUND_NAME = "BG_LINE_SPACE"


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
	var zone = fengliu_get_line_space_zone()
	if zone == null:
		return

	if ZoneService.zones == null:
		return

	if not ZoneService.zones.has(zone):
		ZoneService.zones.push_back(zone)

	var zone_id: int = ZoneService.zones.find(zone)
	if zone_id < 0:
		return

	zone.my_id = zone_id
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


# 本区域对象（替代旧版的 dlc_data.zones[0]）
func fengliu_get_line_space_zone():
	if _fengliu_line_space_zone == null:
		_fengliu_line_space_zone = load(FENGLIU_LINE_SPACE_ZONE_PATH)

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


# 原版按下标取区域：把本区域移到末尾并保持 my_id == 下标（幂等、只动本区域）
func fengliu_ensure_line_space_zone_last(reason: String = "") -> void :
	var zone = fengliu_get_line_space_zone()
	if zone == null:
		return

	if ZoneService.zones == null:
		return

	var our_index: int = ZoneService.zones.find(zone)
	if our_index < 0:
		return

	# 本区域的默认背景收敛（幂等）
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
	var selection_was_our_zone: bool = settings != null and int(settings.get("zone_selected", -1)) == our_index
	var zones_before: String = _fengliu_zone_list_text()

	ZoneService.zones.remove(our_index)
	ZoneService.zones.push_back(zone)

	zone.my_id = ZoneService.zones.size() - 1
	_fengliu_apply_zone_id(zone.my_id)

	if run_was_in_our_zone:
		RunData.current_zone = zone.my_id

	if selection_was_our_zone:
		settings["zone_selected"] = zone.my_id

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


# 本区域 my_id 变化后，把老存档里挂在旧下标上的难度条目复制到新下标（取最大合并）
func _fengliu_migrate_zone_difficulty_info(p_old_id: int, p_new_id: int) -> void :
	if p_old_id < 0 or p_old_id == p_new_id:
		return

	for difficulty_info in difficulties_unlocked:
		if difficulty_info == null:
			continue

		var source: ZoneDifficultyInfo = null
		var target: ZoneDifficultyInfo = null

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


func _fengliu_zone_list_text() -> String:
	var zones_info = []
	for index in range(ZoneService.zones.size()):
		zones_info.append("%d:%s/my_id%d" % [index, ZoneService.zones[index].name, ZoneService.zones[index].my_id])

	return ", ".join(zones_info)


# 一次性 info 日志：区域列表 + 下标/my_id 一致性
func _fengliu_log_zone_state(p_zone_id: int) -> void :
	var zones_info = []
	for zone in ZoneService.zones:
		zones_info.append("%s/my_id%d" % [zone.name, zone.my_id])

	var own_zone = fengliu_get_line_space_zone()
	var own_bosses: int = own_zone.bosses.size() if own_zone != null else 0
	var own_elites: int = own_zone.elites.size() if own_zone != null else 0
	var global_bosses: int = ZoneService.bosses.size() if ZoneService.bosses != null else 0

	ModLoaderLog.info("Line space zone ready: zone_id=%d zones=%d[%s] backgrounds=%d global_bosses=%d (zone bosses=%d, zone elites=%d)" % [p_zone_id, ZoneService.zones.size(), ", ".join(zones_info), ItemService.backgrounds.size(), global_bosses, own_bosses, own_elites], FENGLIU_MOD_ID)

	var mismatch: int = _fengliu_zone_mismatch_count()
	if mismatch != 0:
		ModLoaderLog.warning("Zone id mismatch remains: %d zone(s) have my_id != index (a third-party mod may hardcode its my_id)" % mismatch, FENGLIU_MOD_ID)
