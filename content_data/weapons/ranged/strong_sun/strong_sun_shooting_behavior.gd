extends "res://weapons/shooting_behaviors/ranged_weapon_shooting_behavior.gd"



export (float) var front_offset_degrees = 12.0


func shoot(distance: float) -> void :
	var stats = _parent.current_stats

	var angle: float = _parent.rotation - _parent._current_shoot_spread + deg2rad(rand_range( - front_offset_degrees, front_offset_degrees))
	var projectile = shoot_projectile(angle, Vector2(cos(angle), sin(angle)))
	if is_instance_valid(projectile):
		projectile._hitbox.player_attack_id = _get_next_attack_id()

	stats.nb_projectiles = stats.nb_projectiles - 1
	.shoot(distance)
	stats.nb_projectiles = stats.nb_projectiles + 1
