extends "res://weapons/shooting_behaviors/ranged_weapon_shooting_behavior.gd"

export (int) var burst_shots = 3      # 一轮连发打几颗
export (int) var burst_gap_frames = 10  # 每颗之间的间隔(帧, 60fps)
export (float) var burst_jitter = 0.01  # 每发微小随机偏角，避免全部重叠成一条线


# 覆盖射击逻辑：一轮内连发多颗弹丸（含发射间隔与随机偏角）
func shoot(_distance: float) -> void:
	_parent.set_shooting(true)

	var attack_id: int = _get_next_attack_id()
	for i in burst_shots:
		# 每发都播一次开火音
		SoundManager.play(Utils.get_rand_element(_parent.current_stats.shooting_sounds), _parent.current_stats.sound_db_mod, 0.2)

		# 每发朝武器当前朝向打出去(连发期间武器会自动追踪目标)
		var bullet_rotation: float = _parent.rotation + rand_range(-burst_jitter, burst_jitter)
		var projectile: Node = shoot_projectile(bullet_rotation, Vector2(cos(bullet_rotation), sin(bullet_rotation)))
		if is_instance_valid(projectile):
			projectile._hitbox.player_attack_id = attack_id

		if i < burst_shots - 1:
			yield(get_tree().create_timer(burst_gap_frames / 60.0), "timeout")

	_parent.set_shooting(false)