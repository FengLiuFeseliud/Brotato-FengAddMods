extends Timer

# 鬼火少年脚本

const ZONE_SCENE_PATH = "res://mods-unpacked/FengLiu-FengAddMods/projectiles/purple_zones/purple_zone.tscn"
const ZONE_RADIUS = 45.0
const ZONE_DURATION = 3.0
const ZONE_TICK_INTERVAL = 0.5
# 沿路径的铺片间距
const ZONE_SPACING = 60.0
# 每个本体最多同时存在的片数
const MAX_LIVE_ZONES = 30
const MAX_SPAWNS_PER_TICK = 6
const TELEPORT_DISTANCE = 200.0

export (int) var zone_damage = 2
# 橡皮擦用：区域拦玩家子弹 / 区域常驻（只在本体死亡或离场时清）/ 区域颜色
export (bool) var zone_blocks_bullets = false
export (bool) var zone_persist_until_death = false
export (Color) var zone_color = Color(0.62, 0.28, 1.0, 0.20)

var _last_pos: Vector2 = Vector2.ZERO
var _has_last_pos: bool = false
var _carry: float = 0.0
var _live_zones: Array = []


func _ready() -> void :
	one_shot = false
	if not is_connected("timeout", self, "_on_timeout"):
		var _error = connect("timeout", self, "_on_timeout")

	# 常驻模式：本体「死亡」或「离场」（波次清场等未走死亡流程的情况）时，一次性清掉留下的全部区域
	if zone_persist_until_death:
		var owner_node = get_parent()
		if owner_node != null:
			if owner_node.has_signal("died") and not owner_node.is_connected("died", self, "_on_owner_gone"):
				var _error_died = owner_node.connect("died", self, "_on_owner_gone")
			if not owner_node.is_connected("tree_exiting", self, "_on_owner_gone"):
				var _error_exit = owner_node.connect("tree_exiting", self, "_on_owner_gone")

	if is_stopped():
		start()


# 本体死亡 / 离场：清掉本次留下的所有区域
func _on_owner_gone() -> void :
	for zone in _live_zones:
		if is_instance_valid(zone) and zone.has_method("release"):
			zone.release()
	_live_zones.clear()


func _on_timeout() -> void :
	# 本体死亡后不再留痕
	var parent = get_parent()
	if parent == null or parent.get("dead") == true:
		return

	_prune_zones()

	var current: Vector2 = parent.global_position
	if not _has_last_pos:
		# 首次只记录起点，避免在出生点堆一片
		_last_pos = current
		_has_last_pos = true
		return

	var step: Vector2 = current - _last_pos
	var moved: float = step.length()
	_last_pos = current

	# 瞬移
	if moved > TELEPORT_DISTANCE:
		_carry = 0.0
		return

	# 没动就不铺片
	if moved <= 0.0:
		return

	# 到存活上限就只累积位置、
	if _live_zones.size() >= MAX_LIVE_ZONES:
		_carry = 0.0
		return

	# 距离累积
	var from: Vector2 = current - step
	var traveled: float = 0.0
	var spawned: int = 0
	while _carry + (moved - traveled) >= ZONE_SPACING and spawned < MAX_SPAWNS_PER_TICK:
		traveled += ZONE_SPACING - _carry
		_carry = 0.0
		_spawn_zone(from + step * (traveled / moved), parent)
		spawned += 1
		if _live_zones.size() >= MAX_LIVE_ZONES:
			break
	_carry += moved - traveled


# 清理已被回收的片，保持存活计数准确
func _prune_zones() -> void :
	var alive: Array = []
	for zone in _live_zones:
		if is_instance_valid(zone):
			alive.append(zone)
	_live_zones = alive


# 生成一片紫区
func _spawn_zone(pos: Vector2, owner_node: Node) -> void :
	var main = Utils.get_scene_node()
	if main == null or not main.has_method("add_explosion"):
		return

	var scene = load(ZONE_SCENE_PATH)
	if scene == null:
		return

	var zone = scene.instance()
	main.add_child(zone)
	var ground = main.get_node_or_null("TileMap")
	if ground != null:
		main.move_child(zone, ground.get_index() + 1)
	zone.global_position = pos

	# 伤害默认沿用本体当前伤害（随波次成长），无 stats 时退回导出值；
	# 显式传 0（橡皮擦）时保持 0 ⇒ 无害区（只做视觉 + 擦弹，不结算伤害）
	var dmg: int = zone_damage
	if zone_damage > 0 and owner_node != null and owner_node.get("stats") != null:
		dmg = max(1, int(owner_node.stats.damage))
	# 常驻模式：duration 传 0 ⇒ 紫区不启寿命计时，等本体死亡时 release()
	zone.init_zone(dmg, ZONE_RADIUS, (0.0 if zone_persist_until_death else ZONE_DURATION), ZONE_TICK_INTERVAL)

	if zone.has_method("set_layer_color"):
		zone.set_layer_color(zone_color)

	if zone_blocks_bullets and zone.has_method("set_bullet_blocking"):
		zone.set_bullet_blocking(true)

	_live_zones.append(zone)
