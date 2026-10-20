extends "res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd"

# 武装车辆：一次发射三条互相平行、等间隔的一角鲸子弹，随后沿开火方向冲刺

export (float) var projectile_spacing = 200.0
export (float) var muzzle_offset = 22.0
export (float) var charge_speed = 650.0
export (float) var charge_duration = 0.35
export (float) var charge_mass_multiplier = 5.0

var _unlock_move_timer: Timer
var _original_mass: float = 1.0


func init(parent: Node) -> Node:
	# 记录原始质量，冲刺结束后恢复
	.init(parent)
	_original_mass = _parent.mass
	return self


func _ready() -> void:
	._ready()

	_unlock_move_timer = Timer.new()
	add_child(_unlock_move_timer)
	_unlock_move_timer.wait_time = charge_duration
	_unlock_move_timer.one_shot = true
	_unlock_move_timer.autostart = false
	var _error_timeout = _unlock_move_timer.connect("timeout", self, "on_unlock_move_timer_timeout")


func reset() -> void:
	.reset()

	if _unlock_move_timer != null and _unlock_move_timer.time_left > 0:
		_unlock_move_timer.stop()
		_finish_charge()


func shoot() -> void:
	# 目标失效时不开火，也不进入冲刺
	if _parent == null or _parent.current_target == null or not is_instance_valid(_parent.current_target):
		return

	var direction: Vector2 = (_parent.current_target.global_position - _parent.global_position).normalized()
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT

	# 三发使用相同 rotation 和速度，只在垂直方向等距偏移
	var spawn_data: Array = get_parallel_spawn_data(direction)
	for data in spawn_data:
		spawn_projectile(data["rotation"], data["position"], projectile_speed)

	_shots_taken += 1
	_start_charge(direction)


func get_parallel_spawn_data(direction: Vector2) -> Array:
	# 返回三发子弹的生成位置与统一朝向，便于探针验证
	var dir: Vector2 = direction.normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT

	var perpendicular: Vector2 = Vector2( - dir.y, dir.x)
	var result: Array = []
	for offset in [ - projectile_spacing, 0.0, projectile_spacing]:
		result.append({
			"position": _parent.global_position + dir * muzzle_offset + perpendicular * offset,
			"rotation": dir.angle(),
		})
	return result


func _start_charge(direction: Vector2) -> void:
	# 复用 ChargingAttackBehavior 的冲刺方式：锁定移动方向、临时加速并提高质量
	_parent._move_locked = true
	_parent._current_movement = direction
	_parent.bonus_speed = charge_speed * RunData.current_run_accessibility_settings.speed
	_parent.mass = _original_mass * charge_mass_multiplier
	_unlock_move_timer.start()


func on_unlock_move_timer_timeout() -> void:
	_finish_charge()


func _finish_charge() -> void:
	if _parent == null:
		return

	_parent.bonus_speed = 0
	_parent._move_locked = false
	_parent.mass = _original_mass
	_parent._animation_player.playback_speed = _parent._idle_playback_speed
