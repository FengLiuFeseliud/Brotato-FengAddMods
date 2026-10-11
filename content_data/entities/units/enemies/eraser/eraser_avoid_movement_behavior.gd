extends "res://entities/units/movement_behaviors/movement_behavior.gd"

# 橡皮擦专属移动：主动躲避玩家

export (float) var keep_distance = 320.0
export (float) var keep_distance_randomization = 120.0
export (float) var ring_tolerance = 40.0
export (float) var wall_margin = 90.0
export (float) var jitter_degrees = 20.0
export (float) var jitter_interval = 0.4
# get_target_position() 的前瞻距离
export (float) var target_lookahead = 1000.0

var _ring: float = 320.0
var _jitter: float = 0.0
var _next_jitter_at: float = 0.0
var _orbit_sign: float = 1.0


func _ready() -> void :
	# 每只橡皮擦的环半径不同（群体分散，不会挤成一团）
	_ring = max(0.0, keep_distance + rand_range( - keep_distance_randomization, keep_distance_randomization))
	_orbit_sign = 1.0 if randf() < 0.5 else - 1.0
	_roll_jitter()
	_next_jitter_at = _now() + jitter_interval


func _now() -> float:
	return OS.get_ticks_msec() / 1000.0


func _roll_jitter() -> void :
	_jitter = deg2rad(rand_range( - jitter_degrees, jitter_degrees))


# 要躲的目标：最近的活着玩家（多玩家/联机各躲最近的那个）；没有玩家时退回 current_target
func _get_avoid_target():
	if _parent == null:
		return null

	var best = null
	var best_dist: float = INF
	var players = _parent.players_ref
	if players != null:
		for player in players:
			if player == null or not is_instance_valid(player):
				continue
			if player.get("dead") == true:
				continue
			var dist: float = _parent.global_position.distance_squared_to(player.global_position)
			if dist < best_dist:
				best_dist = dist
				best = player

	if best == null and is_instance_valid(_parent.current_target):
		best = _parent.current_target

	return best


# 把「朝墙」的方向分量剔掉（沿墙滑）
func _remove_wall_components(dir: Vector2) -> Vector2:
	var pos: Vector2 = _parent.global_position
	var min_pos: Vector2 = _parent._min_pos
	var max_pos: Vector2 = _parent._max_pos

	if pos.x <= min_pos.x + wall_margin and dir.x < 0.0:
		dir.x = 0.0
	elif pos.x >= max_pos.x - wall_margin and dir.x > 0.0:
		dir.x = 0.0

	if pos.y <= min_pos.y + wall_margin and dir.y < 0.0:
		dir.y = 0.0
	elif pos.y >= max_pos.y - wall_margin and dir.y > 0.0:
		dir.y = 0.0

	return dir


func get_movement() -> Vector2:
	var target = _get_avoid_target()
	if target == null:
		return Vector2.ZERO

	if _now() >= _next_jitter_at:
		_roll_jitter()
		_next_jitter_at = _now() + jitter_interval

	# 「目标 → 自身」的径向
	var to_self: Vector2 = _parent.global_position - target.global_position
	var dist: float = to_self.length()
	if dist < 0.0001:
		to_self = Vector2(1, 0)
		dist = 0.0
	var away: Vector2 = to_self.normalized()

	var desired: Vector2
	if _ring <= 0.0:
		# 纯逃跑模式（keep_distance = 0）：永远背离玩家
		desired = away
	elif dist < _ring - ring_tolerance:
		# 太近 ⇒ 赶紧拉开
		desired = away
	elif dist > _ring + ring_tolerance:
		# 太远 ⇒ 只靠回环上（不是"冲玩家"，靠到位就转为绕行）
		desired = - away
	else:
		# 环附近 ⇒ 绕着玩家侧向游走
		desired = Vector2( - away.y, away.x) * _orbit_sign

	desired = desired.rotated(_jitter)
	desired = _remove_wall_components(desired)

	if desired.length_squared() < 0.04:
		desired = Vector2( - away.y, away.x) * _orbit_sign
		desired = _remove_wall_components(desired)

	if desired.length_squared() < 0.0001:
		desired = Vector2(_orbit_sign, 0)

	return desired


func get_target_position():
	var dir: Vector2 = get_movement()
	if dir.length_squared() < 0.0001:
		return _parent.global_position
	return _parent.global_position + dir.normalized() * target_lookahead
