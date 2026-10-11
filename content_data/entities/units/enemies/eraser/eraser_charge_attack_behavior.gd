extends "res://entities/units/enemies/attack_behaviors/charging_attack_behavior.gd"

# 橡皮擦的冲刺方向

func set_target() -> void :
	var dir: Vector2 = Vector2.ZERO
	var target = _parent.current_target
	var to_target: Vector2 = Vector2.ZERO
	if target != null and is_instance_valid(target):
		to_target = (target.global_position - _parent.global_position).normalized()

	if _parent.has_method("get_movement"):
		dir = _parent.get_movement()

	if dir.length_squared() < 0.0001:
		dir = - to_target

	if dir.length_squared() > 0.0001 and to_target != Vector2.ZERO and dir.normalized().dot(to_target) > 0.2:
		dir = Vector2( - to_target.y, to_target.x)

	if dir.length_squared() < 0.0001:
		dir = Vector2(1, 0)

	_charge_direction = dir.normalized()
