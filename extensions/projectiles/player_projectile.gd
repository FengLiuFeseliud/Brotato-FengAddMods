extends "res://projectiles/player_projectile.gd"


# 子弹最大倍率
const FENGLIU_BULLET_SCALE_MAX: float = 10.0

var effect_fengliu_bullet_scale = Keys.generate_hash("fengliu_bullet_scale")

# 弹丸根节点自带缩放
var _fengliu_base_projectile_scale: Vector2 = Vector2.ONE

# 动作相关 meta：回池时清理，避免普通子弹复用带出上一次爆炸/动作快照
const FENGLIU_ACTION_META_KEYS = [
	"fengliu_action_snapshot",
	"fengliu_whale_action_snapshot",
	"fengliu_explosion_bullet_effect",
]


# 缓存弹丸根节点基础缩放（发射时叠加玩家体型）
func _ready() -> void:
	._ready()
	# 记录弹丸根节点初始缩放
	_fengliu_base_projectile_scale = scale


# 发射时按开枪玩家的体型设置本颗子弹的大小
func shoot() -> void:
	# 先按玩家体型设置本颗子弹大小，再走原版发射
	_fengliu_apply_player_scale()
	.shoot()


# 按玩家体型与子弹缩放属性调整本颗子弹的缩放
func _fengliu_apply_player_scale() -> void:
	var scale_factor: float = _fengliu_get_player_scale_factor()
	# 缩放无效时保持原样
	if scale_factor <= 0.0:
		return

	# 缩放弹丸根节点，避免 AnimationPlayer 的 Sprite:scale 覆盖
	scale = _fengliu_base_projectile_scale * scale_factor


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
	# 清理动作 meta，避免普通子弹复用池对象时继承爆炸效果
	for meta_key in FENGLIU_ACTION_META_KEYS:
		if has_meta(meta_key):
			remove_meta(meta_key)

	# 还原弹丸缩放，避免污染池对象
	scale = _fengliu_base_projectile_scale
	._return_to_pool()
