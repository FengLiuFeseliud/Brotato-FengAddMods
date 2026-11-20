extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/melee/greatsword_base.gd"


# ============================================================
# 近战动作：大剑旋转扫击
#   角色与剑一起旋转，持续 spin_duration 秒；每 spin_hit_reset_interval 秒
#   重置一次命中忽略列表，剑影按扇区切换并在最后 slash_fade_time 秒淡出。
#   剑影材质全部由动作 .tres 的 ExtResource 提供，脚本不写死路径。
# ------------------------------------------------------------
# 可配置参数：
#   spin_duration                旋转持续秒数
#   spin_hit_reset_interval      命中忽略列表重置间隔
#   slash_fade_time              结束前淡出秒数
#   slash_textures               剑影材质数组（ExtResource）
#   slash_arc_chord              单张剑影弧长
#   slash_length_ratio           剑影弧长占射程比例
#   slash_base_rotation          剑影基础旋转（弧度）
#   slash_canvas_half_ratio      画布半边 / 射程
#   slash_blade_half_ratio       剑身半宽 / 射程
#   slash_radial_offset_ratio    剑影径向偏移 / 射程
#   slash_hitbox_width_scale     剑影宽度并入命中框的倍率
# ============================================================

export(float) var spin_duration
export(float) var spin_hit_reset_interval
export(float) var slash_fade_time
export(Array, Texture) var slash_textures
export(float) var slash_arc_chord
export(float) var slash_length_ratio
export(float) var slash_base_rotation
export(float) var slash_canvas_half_ratio
export(float) var slash_blade_half_ratio
export(float) var slash_radial_offset_ratio
export(float) var slash_hitbox_width_scale

var _fengliu_spin_time_left := 0.0
var _fengliu_hit_reset_time_left := 0.0
var _fengliu_spin_angle := 0.0
var _fengliu_last_slash_segment := -1
var _fengliu_slash_sprite: Sprite = null


func get_args(_player_index: int = -1) -> Array:
	return [str(trigger_count), str(spin_duration), str(reach_multiplier)]


func fengliu_start() -> void:
	.fengliu_start()
	if _fengliu_weapon == null or _fengliu_is_player_dead():
		fengliu_finish()
		return

	_fengliu_save_pose()
	_fengliu_save_player_facing()
	_fengliu_spin_angle = 0.0
	_fengliu_spin_time_left = max(0.01, spin_duration)
	_fengliu_hit_reset_time_left = max(0.01, spin_hit_reset_interval)
	_fengliu_create_slash_sprite()
	_fengliu_apply_spin_pose()
	_fengliu_weapon.enable_hitbox()


func fengliu_update(delta: float) -> void:
	if not _fengliu_active:
		return
	if _fengliu_weapon == null or _fengliu_is_player_dead():
		fengliu_finish()
		return

	_fengliu_spin_angle += _fengliu_get_spin_speed() * delta
	_fengliu_weapon.rotation = _fengliu_spin_angle
	_fengliu_update_player_facing(cos(_fengliu_spin_angle) >= 0.0)
	_fengliu_sync_slash_texture()

	_fengliu_hit_reset_time_left -= delta
	if _fengliu_hit_reset_time_left <= 0.0:
		_fengliu_hit_reset_time_left = max(0.01, spin_hit_reset_interval)
		_fengliu_weapon.disable_hitbox()
		_fengliu_weapon.enable_hitbox()

	_fengliu_spin_time_left -= delta
	if _fengliu_spin_time_left <= 0.0:
		fengliu_finish()
	else:
		_fengliu_update_slash_fade()


func fengliu_process(_delta: float) -> void:
	if not _fengliu_active or _fengliu_weapon == null:
		return

	_fengliu_weapon.rotation = _fengliu_spin_angle
	_fengliu_update_player_facing(cos(_fengliu_spin_angle) >= 0.0)

	var sprite = _fengliu_get_sprite()
	if sprite != null:
		sprite.flip_v = false


func fengliu_is_finished() -> bool:
	return _fengliu_spin_time_left <= 0.0


func fengliu_can_start() -> bool:
	return not _fengliu_active


func fengliu_should_take_over_physics() -> bool:
	return _fengliu_active


func fengliu_should_take_over_process() -> bool:
	return _fengliu_active


func _fengliu_get_spin_speed() -> float:
	return TAU / max(0.05, _fengliu_get_attack_interval())


func _fengliu_create_slash_sprite() -> void:
	if slash_textures == null or slash_textures.size() == 0:
		return
	if _fengliu_slash_sprite != null and is_instance_valid(_fengliu_slash_sprite):
		_fengliu_slash_sprite.queue_free()
	_fengliu_slash_sprite = Sprite.new()
	_fengliu_slash_sprite.visible = false
	_fengliu_slash_sprite.texture = slash_textures[0]
	_fengliu_weapon.add_child(_fengliu_slash_sprite)


func _fengliu_get_slash_tangent_offset_ratio() -> float:
	return slash_canvas_half_ratio + slash_blade_half_ratio


func _fengliu_apply_spin_pose() -> void:
	var radius: float = _fengliu_get_effect_radius()
	var scale_x: float = _fengliu_get_blade_scale_x(radius)
	if _fengliu_weapon == null:
		return

	_fengliu_weapon.position = Vector2.ZERO
	_fengliu_weapon.rotation = 0.0

	var sprite = _fengliu_get_sprite()
	if sprite != null:
		sprite.scale = Vector2(scale_x, 1.0)
		sprite.position = Vector2(radius * 0.5, 0.0)
		sprite.rotation = 0.0

	_fengliu_stretch_spin_hitbox(radius)

	if _fengliu_slash_sprite != null and is_instance_valid(_fengliu_slash_sprite):
		var tangent_offset: float = _fengliu_get_slash_tangent_offset_ratio()
		var slash_scale: float = radius * slash_length_ratio / max(0.001, slash_arc_chord)
		_fengliu_slash_sprite.visible = true
		_fengliu_slash_sprite.position = Vector2(radius * slash_radial_offset_ratio, -radius * tangent_offset)
		_fengliu_slash_sprite.scale = Vector2(slash_scale, slash_scale)
		_fengliu_slash_sprite.rotation = slash_base_rotation
		_fengliu_slash_sprite.modulate.a = 1.0
		_fengliu_last_slash_segment = -1
		_fengliu_sync_slash_texture()


func _fengliu_stretch_spin_hitbox(radius: float) -> void:
	var slash_scale: float = radius * slash_length_ratio / max(0.001, slash_arc_chord)
	var texture_half: float = 96.0
	if slash_textures != null and slash_textures.size() > 0 and slash_textures[0] != null:
		texture_half = float(slash_textures[0].get_width()) * 0.5

	var slash_half_width: float = texture_half * slash_scale * max(0.0, slash_hitbox_width_scale)
	var slash_outer: float = radius * _fengliu_get_slash_tangent_offset_ratio() + slash_half_width
	var blade_half: float = _fengliu_saved_hitbox_extents.y
	var half_width: float = (slash_outer + blade_half) * 0.5
	var y_offset: float = -(slash_outer - blade_half) * 0.5
	_fengliu_stretch_hitbox(radius, half_width, y_offset)


func _fengliu_sync_slash_texture() -> void:
	if _fengliu_slash_sprite == null or not is_instance_valid(_fengliu_slash_sprite):
		return
	if slash_textures == null or slash_textures.size() == 0:
		return

	var sector_count: int = max(1, slash_textures.size())
	var sector_degrees: float = 360.0 / float(sector_count)
	var degrees: float = fposmod(rad2deg(_fengliu_spin_angle), 360.0)
	var segment: int = int(floor((degrees + 0.0001) / sector_degrees)) % sector_count
	if segment == _fengliu_last_slash_segment:
		return

	_fengliu_last_slash_segment = segment
	_fengliu_slash_sprite.texture = slash_textures[segment % slash_textures.size()]


func _fengliu_update_slash_fade() -> void:
	if _fengliu_slash_sprite == null or not is_instance_valid(_fengliu_slash_sprite):
		return
	_fengliu_slash_sprite.modulate.a = clamp(_fengliu_spin_time_left / max(0.05, slash_fade_time), 0.0, 1.0)


func fengliu_on_finish() -> void:
	_fengliu_spin_time_left = 0.0
	if _fengliu_weapon != null:
		_fengliu_weapon.disable_hitbox()
		_fengliu_restore_pose()
		_fengliu_restore_player_facing()

	if _fengliu_slash_sprite != null and is_instance_valid(_fengliu_slash_sprite):
		_fengliu_slash_sprite.queue_free()
	_fengliu_slash_sprite = null
	_fengliu_last_slash_segment = -1
