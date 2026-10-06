extends "res://global/dlc_data.gd"

# 「线条空间」区域按原版 DLC 的方式注册：zones / backgrounds / bosses / elites 全部交给
# 原版 ProgressData._ready() 里的 add_resources() 循环，与「深渊」走完全同一条链路。


# 覆盖: 原版这些数组/字典字段没有默认值（null），先补空，避免 add_resources() 去遍历 null
func _init():
	# 逐个补成空数组/空字典（原版 .tres 里也会把这些字段全写一遍，这里保证脚本实例同样安全）
	zones = []
	backgrounds = []
	bosses = []
	elites = []
	characters = []
	items = []
	weapons = []
	stats = []
	sets = []
	icons = []
	title_screen_backgrounds = []
	entities_items = []
	scene_effect_behaviors = []
	enemy_effect_behaviors = []
	player_effect_behaviors = []
	music_tracks = []
	translations = []
	tracked_items = {}
	tracked_items_hash = {}
	translation_keys_needing_operator = {}
	translation_keys_needing_percent = {}

	._init()


# 覆盖: 追加后把区域 my_id、boss/精英 zone_id 对齐到实际下标（原版按下标取区域）
#   重复调用时原版基类的幂等守卫会跳过追加，这里依旧重新对齐 ⇒ 区域被挪位也能自愈
func add_resources():
	.add_resources()

	var zone_id: int = -1

	for zone in zones:
		var index: int = ZoneService.zones.find(zone)
		if index < 0:
			continue

		zone.my_id = index
		zone_id = index

	# 区域不在列表里（追加被跳过且被别的流程摘掉）时不改 boss/精英的归属
	if zone_id < 0:
		return

	for boss in bosses:
		boss.zone_id = zone_id

	for elite in elites:
		elite.zone_id = zone_id


# 覆盖: 本区域常驻，不随 DLC 开关或旧存档的 run state（enabled_dlcs 不含本数据）被摘掉
func remove_resources():
	pass


# 覆盖: 原版 debug 流程会对 available_dlcs[0] 调 curse_item；本区域不提供诅咒，原样返回
func curse_item(item_data: ItemParentData, player_index: int, turn_randomization_off: bool = false, min_modifier: float = 0.0) -> ItemParentData:
	return item_data
