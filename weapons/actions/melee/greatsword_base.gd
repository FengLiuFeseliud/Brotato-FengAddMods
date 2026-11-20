extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/melee/melee_action.gd"


# ============================================================
# 大剑动作基类
#   为地裂斩 / 旋转扫击提供共享的位姿、命中框、角色翻面与半径辅助。
#   具体材质、场景与玩法数值由子类动作的 .tres 提供。
# ============================================================

export(float) var reach_multiplier

var _fengliu_saved_weapon_position := Vector2.ZERO
var _fengliu_saved_weapon_rotation := 0.0
var _fengliu_saved_sprite_position := Vector2.ZERO
var _fengliu_saved_sprite_scale := Vector2.ONE
var _fengliu_saved_sprite_rotation := 0.0
var _fengliu_saved_hitbox_extents := Vector2.ZERO
var _fengliu_saved_hitbox_collision_position := Vector2.ZERO
var _fengliu_saved_player_sprite_signs := []


func _fengliu_get_sprite():
	if _fengliu_weapon == null:
		return null

	return _fengliu_weapon.sprite


func _fengliu_get_hitbox():
	if _fengliu_weapon == null:
		return null

	return _fengliu_weapon._hitbox


func _fengliu_get_current_stats():
	if _fengliu_weapon == null:
		return null

	return _fengliu_weapon.current_stats


func _fengliu_get_player():
	if _fengliu_weapon == null:
		return null

	if _fengliu_weapon.has_method("fengliu_get_player"):
		return _fengliu_weapon.fengliu_get_player()
	return null


func _fengliu_get_player_index() -> int:
	if _fengliu_weapon == null:
		return -1

	return _fengliu_weapon.player_index


func _fengliu_is_player_dead() -> bool:
	var player = _fengliu_get_player()
	if player == null or not is_instance_valid(player):
		return true

	if "dead" in player and player.dead:
		return true

	return false


func _fengliu_get_effect_radius() -> float:
	var stats = _fengliu_get_current_stats()
	if stats == null:
		return 1.0

	return max(1.0, float(stats.max_range)) * max(0.01, reach_multiplier)


func _fengliu_get_blade_scale_x(radius: float) -> float:
	var sprite = _fengliu_get_sprite()
	var texture_width: float = 225.0
	if sprite != null and sprite.texture != null:
		texture_width = max(1.0, float(sprite.texture.get_width()))

	return max(1.0, radius) / texture_width


func _fengliu_get_attack_interval() -> float:
	var stats = _fengliu_get_current_stats()
	if stats == null:
		return 0.05

	var player_index: int = _fengliu_get_player_index()
	if player_index >= 0:
		var interval: float = stats.get_cooldown_value(player_index, 1.0)
		if interval > 0.0:
			return max(0.05, interval)

	return max(0.05, float(stats.cooldown) / 60.0)


func _fengliu_save_pose() -> void:
	if _fengliu_weapon == null:
		return

	_fengliu_saved_weapon_position = _fengliu_weapon.position
	_fengliu_saved_weapon_rotation = _fengliu_weapon.rotation

	var sprite = _fengliu_get_sprite()
	if sprite != null:
		_fengliu_saved_sprite_position = sprite.position
		_fengliu_saved_sprite_scale = sprite.scale
		_fengliu_saved_sprite_rotation = sprite.rotation

	var hitbox = _fengliu_get_hitbox()
	if hitbox != null:
		var collision = hitbox.get_node_or_null("Collision")
		if collision != null and collision.shape is RectangleShape2D:
			_fengliu_saved_hitbox_extents = collision.shape.extents
			_fengliu_saved_hitbox_collision_position = collision.position


func _fengliu_restore_pose() -> void:
	if _fengliu_weapon == null:
		return

	_fengliu_weapon.position = _fengliu_saved_weapon_position
	_fengliu_weapon.rotation = _fengliu_saved_weapon_rotation

	var sprite = _fengliu_get_sprite()
	if sprite != null:
		sprite.position = _fengliu_saved_sprite_position
		sprite.scale = _fengliu_saved_sprite_scale
		sprite.rotation = _fengliu_saved_sprite_rotation

	var hitbox = _fengliu_get_hitbox()
	if hitbox != null:
		var collision = hitbox.get_node_or_null("Collision")
		if collision != null and collision.shape is RectangleShape2D:
			var shape = collision.shape.duplicate()
			shape.extents = _fengliu_saved_hitbox_extents
			collision.shape = shape
			collision.position = _fengliu_saved_hitbox_collision_position


func _fengliu_stretch_hitbox(radius: float, half_width: float, y_offset: float) -> void:
	var hitbox = _fengliu_get_hitbox()
	if hitbox == null:
		return

	var collision = hitbox.get_node_or_null("Collision")
	if collision == null or not (collision.shape is RectangleShape2D):
		return
		
	var scale_x: float = _fengliu_get_blade_scale_x(radius)
	var shape = collision.shape.duplicate()
	shape.extents = Vector2(max(1.0, radius) * 0.5 / max(0.01, scale_x), half_width)
	collision.shape = shape
	collision.position = Vector2(0.0, y_offset)


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
