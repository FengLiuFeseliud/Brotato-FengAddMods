extends "res://singletons/zone_service.gd"

# 1.2.0 的区域注册方式：区域来自 zone_service.tscn 的 zones 属性（原版 3 个），
# 本 mod 在 _ready 里把自己的 ZoneData 追加到末尾，并保持 my_id == 下标。

const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const FENGLIU_LINE_SPACE_ZONE_PATH = FENGLIU_MOD_DIR + "zones/zone_line_space/zone_line_space_data.tres"

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


func _ready() -> void :
	_fengliu_register_line_space_zone()

	if ProgressData.has_method("fengliu_ensure_line_space_zone_progress"):
		ProgressData.call("fengliu_ensure_line_space_zone_progress")


# 把线条空间区域追加到 ZoneService.zones，并同步 my_id / boss / 精英归属
func _fengliu_register_line_space_zone() -> void :
	if _fengliu_line_space_zone == null:
		_fengliu_line_space_zone = load(FENGLIU_LINE_SPACE_ZONE_PATH)

	if _fengliu_line_space_zone == null:
		ModLoaderLog.error("Failed to load line space zone: %s" % FENGLIU_LINE_SPACE_ZONE_PATH, FENGLIU_MOD_ID)
		return

	if zones == null:
		zones = []

	if not zones.has(_fengliu_line_space_zone):
		zones.push_back(_fengliu_line_space_zone)

	var zone_index: int = zones.find(_fengliu_line_space_zone)
	if zone_index < 0:
		return

	_fengliu_line_space_zone.my_id = zone_index
	_fengliu_apply_zone_id(zone_index)

	ModLoaderLog.info("Line space zone registered: index=%d name=%s bosses=%d elites=%d" % [zone_index, str(_fengliu_line_space_zone.name), _fengliu_line_space_zone.bosses.size(), _fengliu_line_space_zone.elites.size()], FENGLIU_MOD_ID)

	_fengliu_register_entity_items()


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


# 覆盖: 玩家真正进入某个区域时（读档 / 开局 / 换区）再做一次区域下标自愈。
func set_current_zone(p_current_zone: ZoneData) -> void :
	.set_current_zone(p_current_zone)

	if ProgressData.has_method("fengliu_ensure_line_space_zone_last"):
		ProgressData.call("fengliu_ensure_line_space_zone_last", "set current zone")
