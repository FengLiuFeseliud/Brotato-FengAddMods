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

var _last_pos: Vector2 = Vector2.ZERO
var _has_last_pos: bool = false
var _carry: float = 0.0
var _live_zones: Array = []


func _ready() -> void :
	one_shot = false
	if not is_connected("timeout", self, "_on_timeout"):
		var _error = connect("timeout", self, "_on_timeout")

	if is_stopped():
		start()


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

	# 伤害默认沿用本体当前伤害（随波次成长），无 stats 时退回导出值
	var dmg: int = zone_damage
	if owner_node != null and owner_node.get("stats") != null:
		dmg = max(1, int(owner_node.stats.damage))
	zone.init_zone(dmg, ZONE_RADIUS, ZONE_DURATION, ZONE_TICK_INTERVAL)
	_live_zones.append(zone)
