extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/melee/greatsword_base.gd"


# ============================================================
# 近战动作：大剑地裂斩
#   举剑放大 → 下挥（开命中框）→ 落地（关命中框 + 圆周伤害 + 地裂）→ 收剑。
#   地裂场景与材质由动作 .tres 的 ExtResource 提供，脚本不写死路径。
# ------------------------------------------------------------
# 可配置参数：
#   slam_scene                   地裂场景（ExtResource）
#   slam_texture                 地裂材质（ExtResource，可覆盖场景贴图）
#   slam_base_radius             场景命中圆基础半径
#   slam_smoke_amount            烟雾数量
#   slam_sound_db_mod            音量修正
#   slam_duration_scale          总时长 = 攻击间隔 × 该倍率
#   slam_windup_ratio            举剑段占比
#   slam_sweep_ratio             下挥段占比
#   slam_recover_ratio           收剑段占比
#   slam_min_duration            总时长下限
#   slam_max_duration            总时长上限
#   slam_pose_angle_start        举剑起始角度
#   slam_pose_angle_end          落地角度
#   ground_layer_name            地裂挂载的地面层名称
# ============================================================

export(PackedScene) var slam_scene
export(Texture) var slam_texture
export(float) var slam_base_radius
export(int) var slam_smoke_amount
export(int) var slam_sound_db_mod
export(float) var slam_duration_scale
export(float) var slam_windup_ratio
export(float) var slam_sweep_ratio
export(float) var slam_recover_ratio
export(float) var slam_min_duration
export(float) var slam_max_duration
export(float) var slam_pose_angle_start
export(float) var slam_pose_angle_end
export(String) var ground_layer_name

var _fengliu_slam_time := 0.0
var _fengliu_slam_windup := 0.0
var _fengliu_slam_sweep := 0.0
var _fengliu_slam_recover := 0.0
var _fengliu_slam_total := 0.0
var _fengliu_slam_sweep_started := false
var _fengliu_slam_impact_done := false


func get_args(_player_index: int = -1) -> Array:
	return [str(trigger_count), str(reach_multiplier)]


func fengliu_start() -> void:
	.fengliu_start()
	if _fengliu_weapon == null or _fengliu_is_player_dead():
		fengliu_finish()
		return

	_fengliu_save_pose()
	_fengliu_save_player_facing()
	_fengliu_update_slam_durations()
	_fengliu_slam_time = 0.0
	_fengliu_slam_sweep_started = false
	_fengliu_slam_impact_done = false
	_fengliu_update_player_facing(true)
	_fengliu_apply_slam_pose(0.0)


func fengliu_update(delta: float) -> void:
	if not _fengliu_active:
		return

	if _fengliu_weapon == null or _fengliu_is_player_dead():
		fengliu_finish()
		return

	var radius: float = _fengliu_get_effect_radius()
	_fengliu_slam_time += delta

	if not _fengliu_slam_sweep_started and _fengliu_slam_time >= _fengliu_slam_windup:
		_fengliu_slam_sweep_started = true
		_fengliu_stretch_hitbox(radius, _fengliu_saved_hitbox_extents.y, 0.0)
		_fengliu_weapon.enable_hitbox()

	if not _fengliu_slam_impact_done and _fengliu_slam_time >= _fengliu_slam_windup + _fengliu_slam_sweep:
		_fengliu_slam_impact_done = true
		_fengliu_weapon.disable_hitbox()
		_fengliu_spawn_slam_explosion(_fengliu_get_player(), radius)

	_fengliu_apply_slam_pose(_fengliu_slam_time)

	if _fengliu_slam_time >= _fengliu_slam_total:
		fengliu_finish()


func fengliu_process(_delta: float) -> void:
	if not _fengliu_active:
		return

	_fengliu_apply_slam_pose(_fengliu_slam_time)


func fengliu_is_finished() -> bool:
	return _fengliu_slam_total > 0.0 and _fengliu_slam_time >= _fengliu_slam_total


func fengliu_can_start() -> bool:
	return not _fengliu_active


func fengliu_should_take_over_physics() -> bool:
	return _fengliu_active


func fengliu_should_take_over_process() -> bool:
	return _fengliu_active


func _fengliu_update_slam_durations() -> void:
	_fengliu_slam_total = max(0.01, clamp(
		_fengliu_get_attack_interval() * slam_duration_scale,
		slam_min_duration,
		slam_max_duration
	))
	_fengliu_slam_windup = _fengliu_slam_total * slam_windup_ratio
	_fengliu_slam_sweep = _fengliu_slam_total * slam_sweep_ratio
	_fengliu_slam_recover = _fengliu_slam_total * slam_recover_ratio


func _fengliu_get_slam_pose_at(elapsed: float) -> Array:
	var windup_end: float = _fengliu_slam_windup
	var sweep_end: float = _fengliu_slam_windup + _fengliu_slam_sweep

	if elapsed <= windup_end:
		var t: float = clamp(elapsed / max(0.001, _fengliu_slam_windup), 0.0, 1.0)
		return [lerp(0.0, slam_pose_angle_start, t), t]

	if elapsed <= sweep_end:
		var t: float = clamp((elapsed - windup_end) / max(0.001, _fengliu_slam_sweep), 0.0, 1.0)
		return [lerp(slam_pose_angle_start, slam_pose_angle_end, t), 1.0]

	var t2: float = clamp((elapsed - sweep_end) / max(0.001, _fengliu_slam_recover), 0.0, 1.0)
	return [slam_pose_angle_end, 1.0 - t2]


func _fengliu_apply_slam_pose(elapsed: float) -> void:
	if _fengliu_weapon == null:
		return

	var radius: float = _fengliu_get_effect_radius()
	var target_scale: float = _fengliu_get_blade_scale_x(radius)
	var pose: Array = _fengliu_get_slam_pose_at(elapsed)
	var grow: float = pose[1]
	var base_scale: float = _fengliu_saved_sprite_scale.x

	_fengliu_weapon.position = Vector2.ZERO
	_fengliu_weapon.rotation = pose[0]

	var sprite = _fengliu_get_sprite()
	if sprite != null:
		sprite.position = Vector2(radius * 0.5, 0.0)
		sprite.rotation = 0.0
		sprite.scale = Vector2(lerp(base_scale, target_scale, grow), _fengliu_saved_sprite_scale.y)


func _fengliu_spawn_slam_explosion(player, radius: float) -> void:
	if slam_scene == null or _fengliu_weapon == null:
		return
		
	if player == null or not is_instance_valid(player):
		return

	var effect = ExplodingEffect.new()
	effect.explosion_scene = slam_scene
	effect.scale = radius / max(0.01, slam_base_radius)
	effect.base_smoke_amount = slam_smoke_amount
	effect.sound_db_mod = slam_sound_db_mod

	var args = WeaponServiceExplodeArgs.new()
	args.pos = player.global_position
	args.damage = _fengliu_weapon.current_stats.damage
	args.scaling_stats = _fengliu_weapon.current_stats.scaling_stats
	args.accuracy = _fengliu_weapon.current_stats.accuracy
	args.crit_chance = _fengliu_weapon.current_stats.crit_chance
	var player_index: int = _fengliu_get_player_index()
	if player_index >= 0:
		args.crit_chance += Utils.get_capped_stat(Keys.stat_crit_chance_hash, player_index) / 100.0
	args.crit_damage = _fengliu_weapon.current_stats.crit_damage
	args.from_player_index = player_index
	args.from = _fengliu_weapon
	args.burning_data = _fengliu_weapon.current_stats.burning_data

	var explosion = WeaponService.explode(effect, args)
	if explosion == null or not is_instance_valid(explosion):
		var main_fallback = Utils.get_scene_node()
		if main_fallback == null:
			return
		explosion = slam_scene.instance()
		explosion.player_index = player_index
		explosion.global_position = args.pos
		explosion.set_damage(args)
		explosion.set_area(effect.scale)
		explosion.set_from(_fengliu_weapon)
		main_fallback.add_explosion(explosion)
		explosion.start_explosion()

	var main = Utils.get_scene_node()
	var ground_layer = null
	if main != null and ground_layer_name != "":
		ground_layer = main.get_node_or_null(ground_layer_name)
	if ground_layer != null:
		var old_parent = explosion.get_parent()
		if old_parent != null:
			old_parent.remove_child(explosion)
		ground_layer.add_child(explosion)
		explosion.global_position = args.pos

	var crack_sprite = explosion.get_node_or_null("Sprite")
	if crack_sprite != null:
		crack_sprite.modulate.a = 1.0
		crack_sprite.self_modulate = Color(1, 1, 1, 1)
		if slam_texture != null:
			crack_sprite.texture = slam_texture

	explosion.connect("hit_something", _fengliu_weapon, "on_weapon_hit_something", [explosion._hitbox])
	if not explosion.is_connected("killed_something", _fengliu_weapon, "on_killed_something"):
		explosion.connect("killed_something", _fengliu_weapon, "on_killed_something", [explosion._hitbox])


func fengliu_on_finish() -> void:
	_fengliu_slam_time = 0.0
	_fengliu_slam_sweep_started = false
	_fengliu_slam_impact_done = false
	if _fengliu_weapon != null:
		_fengliu_weapon.disable_hitbox()
		_fengliu_restore_pose()
		_fengliu_restore_player_facing()
