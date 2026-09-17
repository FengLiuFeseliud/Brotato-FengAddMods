extends "res://weapons/shooting_behaviors/ranged_weapon_shooting_behavior.gd"



export (float) var front_offset_degrees = 12.0


func shoot(distance: float) -> void :
	# 以武器朝向为中心，在正面偏角内随机取一个发射角
	var stats = _parent.current_stats

	var angle: float = _parent.rotation - _parent._current_shoot_spread + deg2rad(rand_range( - front_offset_degrees, front_offset_degrees))
	var projectile = shoot_projectile(angle, Vector2(cos(angle), sin(angle)))
	if is_instance_valid(projectile):
		# 同一轮射击共用一个攻击 ID，避免重复结算
		projectile._hitbox.player_attack_id = _get_next_attack_id()

	# 临时扣减弹丸数后交给基类处理剩余弹丸，最后还原计数
	stats.nb_projectiles = stats.nb_projectiles - 1
	.shoot(distance)
	stats.nb_projectiles = stats.nb_projectiles + 1
