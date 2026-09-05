extends "res://projectiles/player_projectile.gd"


# 子弹最大倍率
const FENGLIU_BULLET_SCALE_MAX: float = 10.0

var effect_fengliu_bullet_scale = Keys.generate_hash("fengliu_bullet_scale")

# 子弹场景自带缩放
var _fengliu_base_sprite_scale: Vector2 = Vector2.ONE
var _fengliu_base_hitbox_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	._ready()
	if is_instance_valid(_sprite):
		_fengliu_base_sprite_scale = _sprite.scale
	if is_instance_valid(_hitbox):
		_fengliu_base_hitbox_scale = _hitbox.scale


# 发射时按开枪玩家的体型设置本颗子弹的大小
func shoot() -> void:
	_fengliu_apply_player_scale()
	.shoot()


# 按玩家体型与子弹缩放属性调整本颗子弹的缩放
func _fengliu_apply_player_scale() -> void:
	var scale_factor: float = _fengliu_get_player_scale_factor()
	if scale_factor <= 0.0:
		return

	_sprite.scale = _fengliu_base_sprite_scale * scale_factor
	_hitbox.scale = _fengliu_base_hitbox_scale * scale_factor


# 从子弹归属者缩放
func _fengliu_get_player_scale_factor() -> float:
	var from = _hitbox.from
	var player_index = from.get("player_index")
	if not (player_index is int) or player_index < 0:
		# 非玩家武器不缩放
		return 1.0

	var main = Utils.get_scene_node()
	var players = main.get("_players") if main != null else null
	if players == null or player_index >= players.size():
		return 1.0

	var player = players[player_index]
	var scale_factor: float = player.scale.x

	var effect = RunData.get_player_effect(effect_fengliu_bullet_scale, player_index)
	if effect is int and effect != 0:
		scale_factor += effect / 100.0

	if scale_factor <= 0.0:
		return 1.0

	return min(scale_factor, FENGLIU_BULLET_SCALE_MAX)


# 子弹回池时还原缩放，避免污染之后取用的子弹
func _return_to_pool() -> void:
	_sprite.scale = _fengliu_base_sprite_scale
	_hitbox.scale = _fengliu_base_hitbox_scale
	._return_to_pool()
