extends "res://projectiles/player_projectile.gd"


# --------------------------------------------------------------------
# 玩家追踪子弹
# 默认每个物理帧扫描敌人，朝索敌圈内最近的、存活、未被本颗子弹打过、且仍在圈内的敌人平滑转向。
# --------------------------------------------------------------------


export (float) var tracking_turn_strength = 0.01  # 转向力度，越大拐得越急
export (int) var tracking_scan_every_x_frames = 1  # 每隔几帧重新索敌；子弹/怪很多时可调大省性能

onready var _target_trigger_collision = $TargetTriggerHitbox/Collision

var _tracking_target = null
var _tracking_speed: float = 0.0
var _frames_since_scan: int = 0
var _entity_spawner_ref = null


func _physics_process(delta: float) -> void:
	._physics_process(delta)
	if _hitbox == null or not _hitbox.active:
		return  # 子弹正在停止 / 躺在对象池里，跳过

	# 周期性挑选最近敌人作为目标
	_frames_since_scan += 1
	if _frames_since_scan >= tracking_scan_every_x_frames:
		_frames_since_scan = 0
		_tracking_target = _get_nearest_enemy_in_range()

	# 校验缓存目标
	if _tracking_target != null and not _is_valid_tracking_enemy(_tracking_target):
		_tracking_target = null

	if _tracking_target != null:
		var to_target: Vector2 = _tracking_target.global_position - global_position
		var dist_sq: float = to_target.length_squared()
		if dist_sq > 0.0 and dist_sq <= _get_tracking_radius_sq():
			var direction: Vector2 = to_target.normalized()
			velocity = velocity.linear_interpolate(direction * _tracking_speed, tracking_turn_strength)
			velocity = velocity.normalized() * _tracking_speed
		else:
			_tracking_target = null  # 已出圈

	rotation = velocity.angle()


func shoot_ex(p_from: Node, pos: Vector2, p_velocity: Vector2, p_rotation: float, p_weapon_stats: WeaponStats, damage_tracking_key: int, effects: Array, hitbox_args: Hitbox.HitboxArgs, knockback_direction: Vector2) -> void:
	_tracking_target = null
	_tracking_speed = 0.0
	_frames_since_scan = tracking_scan_every_x_frames  # 让第一帧立即索敌
	.shoot_ex(p_from, pos, p_velocity, p_rotation, p_weapon_stats, damage_tracking_key, effects, hitbox_args, knockback_direction)
	_tracking_speed = velocity.length()


func _return_to_pool() -> void:
	_tracking_target = null
	_tracking_speed = 0.0
	._return_to_pool()


# 在索敌圈内找出最近的、还能追踪的敌人 没有则返回 null
func _get_nearest_enemy_in_range() -> Node:
	var radius_sq: float = _get_tracking_radius_sq()
	if radius_sq <= 0.0:
		return null
	var enemies: Array = _get_all_enemies()
	var pos: Vector2 = global_position
	var best: Node = null
	var best_dist_sq: float = INF
	for enemy in enemies:
		if not _is_valid_tracking_enemy(enemy):
			continue
		var dist_sq: float = pos.distance_squared_to(enemy.global_position)
		if dist_sq <= radius_sq and dist_sq < best_dist_sq:
			best = enemy
			best_dist_sq = dist_sq
	return best


# 该敌人是否还能被追踪
func _is_valid_tracking_enemy(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
		
	if enemy.is_queued_for_deletion():
		return false

	if enemy.dead:
		return false

	if _hitbox.ignored_objects.has(enemy):
		return false
	return true


# 从当前主场景拿到所有敌人（缓存 EntitySpawner 引用）
func _get_all_enemies() -> Array:
	if _entity_spawner_ref == null or not is_instance_valid(_entity_spawner_ref):
		var main = get_tree().current_scene
		if main == null:
			return []
		_entity_spawner_ref = main.get("_entity_spawner")
	if _entity_spawner_ref == null or not is_instance_valid(_entity_spawner_ref):
		return []
	return _entity_spawner_ref.get_all_enemies(false)  # false = 排除被魅惑（已转友方）的敌人


# 读取索敌半径（来自 TargetTriggerHitbox/Collision 上的圆）
func _get_tracking_radius() -> float:
	if _target_trigger_collision != null and is_instance_valid(_target_trigger_collision) and _target_trigger_collision.shape is CircleShape2D:
		return _target_trigger_collision.shape.radius
	return 0.0


func _get_tracking_radius_sq() -> float:
	var radius: float = _get_tracking_radius()
	return radius * radius