extends "res://singletons/zone_service.gd"

# 1.2.0 的区域注册方式

const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const FENGLIU_LINE_SPACE_ZONE_PATH = FENGLIU_MOD_DIR + "zones/zone_line_space/zone_line_space_data.tres"
# 与 zone_line_space_data.tres 及 boss/elite .tres 的 my_id/zone_id 保持一致
const FENGLIU_LINE_SPACE_ZONE_ID: int = 3

# 1.2.0 没有旧 DLCData 的 entities_items 通道，图鉴条目在本 mod 注册区域时手动追加
const FENGLIU_LINE_SPACE_ENTITY_ITEMS = [
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/big_apartment/big_apartment_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/hei/hei_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/heiche/heiche_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/lan/lan_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/lanche/lanche_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/hong/hong_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/apartment/apartment_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/metro/metro_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/guihuo/guihuo_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/eraser/eraser_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/umbrella/umbrella_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/neutrals/trash_can/trash_can_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/train_station/train_station_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/rail_train/rail_train_car_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/truck/truck_item.tres",
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/armed_vehicle/armed_vehicle_item.tres",
]


var _fengliu_line_space_zone = null
var _fengliu_zone_registration_logged: bool = false
var _fengliu_duplicate_zone_ids_logged: bool = false


func _ready() -> void :
	fengliu_ensure_line_space_zone_registered()

	if ProgressData.has_method("fengliu_ensure_line_space_zone_progress"):
		ProgressData.call("fengliu_ensure_line_space_zone_progress")


# 注册（幂等）：按 my_id 查找已有实例，缺失才复制 .tres 并追加；注册后统一
# my_id / boss / 精英归属。参考 NCL：my_id 固定，不随数组下标变化。
func fengliu_ensure_line_space_zone_registered():
	if zones == null:
		zones = []

	var zone = fengliu_get_line_space_zone()
	if zone == null:
		zone = _fengliu_create_line_space_zone()

	if zone == null:
		return null

	if not zones.has(zone):
		zones.push_back(zone)

	_fengliu_line_space_zone = zone
	_fengliu_apply_zone_id(FENGLIU_LINE_SPACE_ZONE_ID)
	_fengliu_check_duplicate_zone_ids()

	if not _fengliu_zone_registration_logged:
		_fengliu_zone_registration_logged = true
		ModLoaderLog.info("Line space zone registered: my_id=%d index=%d name=%s bosses=%d elites=%d" % [int(zone.my_id), zones.find(zone), str(zone.name), zone.bosses.size(), zone.elites.size()], FENGLIU_MOD_ID)

	_fengliu_register_entity_items()

	return zone


# 已注册的线条空间区域（按稳定 my_id 查找，兼容 NCL 复制后的实例）
func fengliu_get_line_space_zone():
	if zones != null:
		for zone in zones:
			if zone != null and int(zone.my_id) == FENGLIU_LINE_SPACE_ZONE_ID:
				_fengliu_line_space_zone = zone
				return zone

	return _fengliu_line_space_zone


func fengliu_get_line_space_zone_id() -> int:
	return FENGLIU_LINE_SPACE_ZONE_ID


# 与 NCL 的 NewContent.add_resources() 一致：复制一份再注册，避免改写资源缓存
func _fengliu_create_line_space_zone():
	var source = load(FENGLIU_LINE_SPACE_ZONE_PATH)
	if source == null:
		ModLoaderLog.error("Failed to load line space zone: %s" % FENGLIU_LINE_SPACE_ZONE_PATH, FENGLIU_MOD_ID)
		return null

	if int(source.my_id) != FENGLIU_LINE_SPACE_ZONE_ID:
		ModLoaderLog.warning("Line space zone my_id=%d in .tres, forced to %d" % [int(source.my_id), FENGLIU_LINE_SPACE_ZONE_ID], FENGLIU_MOD_ID)

	var zone = source.duplicate()
	zone.my_id = FENGLIU_LINE_SPACE_ZONE_ID
	if source.bosses != null:
		zone.bosses = source.bosses.duplicate()
	if source.elites != null:
		zone.elites = source.elites.duplicate()
	if source.default_backgrounds != null:
		zone.default_backgrounds = source.default_backgrounds.duplicate()

	return zone


# 兼容旧调用名
func _fengliu_register_line_space_zone() -> void :
	fengliu_ensure_line_space_zone_registered()


func _fengliu_check_duplicate_zone_ids() -> void:
	var seen: Dictionary = {}
	var duplicates: Array = []

	for zone in zones:
		if zone == null:
			continue

		var zone_id: int = int(zone.my_id)
		if seen.has(zone_id):
			duplicates.push_back(str(zone_id))
		else:
			seen[zone_id] = true

	if duplicates.size() > 0 and not _fengliu_duplicate_zone_ids_logged:
		_fengliu_duplicate_zone_ids_logged = true
		ModLoaderLog.error("Duplicate zone my_id detected: %s" % ", ".join(duplicates), FENGLIU_MOD_ID)


# 把本区域的敌人/中立图鉴条目追加到 ItemService.entities（幂等）
func _fengliu_register_entity_items() -> void :
	if ItemService.entities == null:
		return

	var added: int = 0
	for path in FENGLIU_LINE_SPACE_ENTITY_ITEMS:
		var item = load(path)
		if item == null:
			ModLoaderLog.warning("Failed to load entity item: %s" % path, FENGLIU_MOD_ID)
			continue

		if not ItemService.entities.has(item):
			ItemService.entities.push_back(item)
			added += 1

	if added > 0:
		ModLoaderLog.info("Line space entity items registered: added=%d total=%d" % [added, ItemService.entities.size()], FENGLIU_MOD_ID)


func _fengliu_apply_zone_id(p_zone_id: int) -> void :
	if _fengliu_line_space_zone == null:
		return

	for boss in _fengliu_line_space_zone.bosses:
		if boss != null:
			boss.zone_id = p_zone_id

	for elite in _fengliu_line_space_zone.elites:
		if elite != null:
			elite.zone_id = p_zone_id


# 覆盖: 玩家真正进入某个区域时（读档 / 开局 / 换区）补一次区域进度（幂等）
func set_current_zone(p_current_zone: ZoneData) -> void :
	.set_current_zone(p_current_zone)

	if ProgressData.has_method("fengliu_ensure_line_space_zone_progress"):
		ProgressData.call("fengliu_ensure_line_space_zone_progress")
