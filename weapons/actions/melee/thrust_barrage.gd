extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/melee/melee_action.gd"


# ============================================================
# 近战动作：连刺
#   触发后持续 duration 秒，以指定动画速度与冷却倍率连续攻击；
#   连刺期间强制开火（无目标/移动也戳刺），并锁定触发瞬间的武器朝向与角色面向。
#   连刺期间目标切换时，将锁定朝向更新为新目标方向；目标不变时保持固定。
#   当 .tres 配置为动画 ×2、冷却 ×0.5 时，攻击频率 = 原攻速的 2 倍。
#   所有参数均由动作 .tres 提供，脚本内不写死次数、持续时间与倍率。
# ------------------------------------------------------------
# 可配置参数：
#   duration                     持续秒数
#   animation_speed_multiplier   动画速度倍率
#   cooldown_multiplier          冷却倍率
#   attack_type_override         -1 保持武器自身；0 戳刺；1 横扫
#   shorten_cooldown_on_start    触发瞬间是否压缩当前冷却
#   compensate_recoil_duration   是否补偿 recoil_duration 保证严格倍率
#   min_cooldown_ticks           冷却下限（帧）
#   block_normal_shoot / count_as_normal_attack 由通用动作基类提供
# ============================================================

export(float) var duration
export(float) var animation_speed_multiplier
export(float) var cooldown_multiplier
export(int) var attack_type_override
export(bool) var shorten_cooldown_on_start
export(bool) var compensate_recoil_duration
export(float) var min_cooldown_ticks

var _fengliu_time_left := 0.0
var _fengliu_locked_rotation := 0.0
var _fengliu_locked_target = null
var _fengliu_saved_player_sprite_signs := []


func get_args(_player_index: int = -1) -> Array:
	return [str(trigger_count), str(duration), str(animation_speed_multiplier)]


func fengliu_start() -> void:
	.fengliu_start()
	if _fengliu_weapon == null or not is_instance_valid(_fengliu_weapon):
		fengliu_finish()
		return

	_fengliu_locked_rotation = _fengliu_weapon.rotation
	_fengliu_locked_target = _fengliu_get_current_target()
	_fengliu_save_player_facing()
	_fengliu_update_player_facing(_fengliu_is_locked_facing_right())
	_fengliu_time_left = max(0.01, duration)
	if shorten_cooldown_on_start and _fengliu_weapon.has_method("fengliu_shorten_current_cooldown"):
		_fengliu_weapon.fengliu_shorten_current_cooldown()


func fengliu_update(delta: float) -> void:
	if not _fengliu_active:
		return

	_fengliu_update_player_facing(_fengliu_is_locked_facing_right())
	_fengliu_time_left -= delta
	if _fengliu_time_left <= 0.0:
		fengliu_finish()


func fengliu_process(_delta: float) -> void:
	if not _fengliu_active:
		return

	_fengliu_update_player_facing(_fengliu_is_locked_facing_right())


func fengliu_is_finished() -> bool:
	return _fengliu_time_left <= 0.0


func fengliu_can_start() -> bool:
	return not _fengliu_active


func fengliu_should_take_over_process() -> bool:
	return _fengliu_active


func fengliu_get_attack_type_override() -> int:
	if not _fengliu_active:
		return -1

	if attack_type_override < -1 or attack_type_override > 1:
		return -1

	return attack_type_override


func fengliu_should_force_shoot() -> bool:
	return _fengliu_active


func fengliu_should_lock_rotation() -> bool:
	return _fengliu_active


func fengliu_get_locked_rotation() -> float:
	return _fengliu_locked_rotation


func fengliu_sync_aim_target() -> void:
	if not _fengliu_active:
		return

	var target = _fengliu_get_current_target()
	if target == _fengliu_locked_target:
		return

	_fengliu_locked_target = target
	if target == null:
		return

	_fengliu_locked_rotation = _fengliu_get_direction_to_target(target)
	_fengliu_update_player_facing(_fengliu_is_locked_facing_right())


func _fengliu_get_current_target():
	if _fengliu_weapon == null or not is_instance_valid(_fengliu_weapon):
		return null

	if _fengliu_weapon.has_method("fengliu_get_aim_target"):
		return _fengliu_weapon.fengliu_get_aim_target()

	return null


func _fengliu_get_direction_to_target(target) -> float:
	if target == null or not is_instance_valid(target):
		return _fengliu_locked_rotation

	if _fengliu_weapon != null and is_instance_valid(_fengliu_weapon) and _fengliu_weapon.has_method("fengliu_get_target_direction"):
		return _fengliu_weapon.fengliu_get_target_direction(target)

	return _fengliu_locked_rotation


func _fengliu_is_locked_facing_right() -> bool:
	return cos(_fengliu_locked_rotation) >= 0.0


func _fengliu_get_player():
	if _fengliu_weapon == null or not is_instance_valid(_fengliu_weapon):
		return null

	if _fengliu_weapon.has_method("fengliu_get_player"):
		return _fengliu_weapon.fengliu_get_player()

	return null


func _fengliu_save_player_facing() -> void:
	_fengliu_saved_player_sprite_signs.clear()

	var player = _fengliu_get_player()
	if player == null:
		return

	var player_sprites = player.get("_sprites")
	if player_sprites == null:
		return

	for player_sprite in player_sprites:
		if player_sprite == null or not is_instance_valid(player_sprite):
			_fengliu_saved_player_sprite_signs.push_back(1.0)
			continue

		_fengliu_saved_player_sprite_signs.push_back(-1.0 if player_sprite.scale.x < 0.0 else 1.0)


func _fengliu_update_player_facing(facing_right: bool) -> void:
	var player = _fengliu_get_player()
	if player == null:
		return

	var player_sprites = player.get("_sprites")
	if player_sprites == null:
		return

	var sign_x: float = 1.0 if facing_right else -1.0
	for player_sprite in player_sprites:
		if player_sprite == null or not is_instance_valid(player_sprite):
			continue

		player_sprite.scale.x = sign_x * abs(player_sprite.scale.x)


func _fengliu_restore_player_facing() -> void:
	var player = _fengliu_get_player()
	if player == null:
		return

	var player_sprites = player.get("_sprites")
	if player_sprites == null:
		return

	for i in player_sprites.size():
		var player_sprite = player_sprites[i]
		if player_sprite == null or not is_instance_valid(player_sprite):
			continue

		var saved_sign: float = _fengliu_saved_player_sprite_signs[i] if i < _fengliu_saved_player_sprite_signs.size() else 1.0
		player_sprite.scale.x = saved_sign * abs(player_sprite.scale.x)


func fengliu_get_animation_speed_multiplier() -> float:
	if not _fengliu_active:
		return 1.0
		
	return max(0.01, animation_speed_multiplier)


func fengliu_modify_cooldown(base_cooldown: float) -> float:
	if not _fengliu_active:
		return base_cooldown

	var animation_multiplier: float = max(0.01, animation_speed_multiplier)
	var cooldown_scale: float = max(0.0, cooldown_multiplier)
	var modified_cooldown: float = base_cooldown * cooldown_scale

	# 动画加速不会缩短 recoil_duration，按公式扣掉这部分，保证总间隔等于设定倍率
	if compensate_recoil_duration:
		var recoil_ticks: float = 0.0
		if _fengliu_weapon != null and _fengliu_weapon.current_stats != null:
			recoil_ticks = _fengliu_weapon.current_stats.recoil_duration * 60.0
		modified_cooldown -= recoil_ticks * (1.0 - 1.0 / animation_multiplier)

	return max(max(1.0, min_cooldown_ticks), modified_cooldown)


func fengliu_on_finish() -> void:
	_fengliu_restore_player_facing()
	_fengliu_time_left = 0.0
	_fengliu_locked_rotation = 0.0
	_fengliu_locked_target = null
