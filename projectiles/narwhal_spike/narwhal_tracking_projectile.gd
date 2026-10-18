extends "res://projectiles/bullet_enemy/enemy_projectile.gd"

# 追踪玩家的一角鲸尖刺（敌方子弹）：每帧朝最近的存活玩家平滑转向，速度保持不变
# 追踪思路参考 player_tracking_projectile.gd，目标从「敌方单位」换成「玩家」

export (float) var tracking_turn_strength = 0.08
export (float) var tracking_radius = 420.0

var _tracking_target = null
var _tracking_speed: float = 0.0


func shoot() -> void :
	# 每次发射重置追踪状态，并按最终初速取追踪速度
	_tracking_target = null
	_tracking_speed = 0.0
	.shoot()
	_tracking_speed = velocity.length()


func _physics_process(delta: float) -> void :
	# 先按基类位移，再朝最近玩家缓转（没有玩家时保持直线）
	._physics_process(delta)
	if _hitbox == null or not _hitbox.active:
		return
	if _tracking_speed <= 0.0:
		_tracking_speed = velocity.length()
		if _tracking_speed <= 0.0:
			return
	_tracking_target = _get_nearest_player()
	if _tracking_target != null:
		var to_target: Vector2 = _tracking_target.global_position - global_position
		if to_target.length_squared() <= tracking_radius * tracking_radius:
			var direction: Vector2 = to_target.normalized()
			velocity = velocity.linear_interpolate(direction * _tracking_speed, tracking_turn_strength)
			velocity = velocity.normalized() * _tracking_speed
		else:
			_tracking_target = null
	rotation = velocity.angle()


func _return_to_pool() -> void :
	# 回池前清空追踪状态，避免复用上一发的目标
	_tracking_target = null
	_tracking_speed = 0.0
	._return_to_pool()


func _get_nearest_player():
	# 从当前场景取最近的存活玩家（没有玩家时返回 null）
	var main = Utils.get_scene_node()
	if main == null:
		return null
	var players = main.get("_players")
	if players == null:
		return null
	var pos: Vector2 = global_position
	var best = null
	var best_dist_sq: float = INF
	for player_index in RunData.get_player_count():
		var player = main._players[player_index]
		if player == null or not is_instance_valid(player) or player.dead:
			continue
		var dist_sq: float = pos.distance_squared_to(player.global_position)
		if dist_sq < best_dist_sq:
			best = player
			best_dist_sq = dist_sq
	return best
