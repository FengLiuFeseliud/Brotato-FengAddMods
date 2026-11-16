extends Node2D


# ============================================================
# 陨石
#   从右上高处按轨迹角斜向砸向目标点（＝施放瞬间角色所在位置），
#   落地时调用 WeaponService.explode() 造成范围伤害。
#   视觉方向与位置由 meteor.png 材质本身决定：本脚本不做旋转、不加偏移。
#   生成方：content_data/weapons/ranged/universal_pull/universal_pull.gd
# ============================================================

signal explosion_created(explosion)

# 轨迹角（相对水平，度）
const FALL_ANGLE_DEGREES := 35.0
# 起点到落点的路径总长（像素）
const FALL_DISTANCE := 1300.0
# 下落时长（秒）
const FALL_DURATION := 3.0

var _target_pos: Vector2 = Vector2.ZERO
var _exploding_effect: ExplodingEffect = null
var _explode_args: WeaponServiceExplodeArgs = null
var _start_pos: Vector2 = Vector2.ZERO
var _elapsed := 0.0
var _landed := false


# 起点相对落点的偏移：右上高处，按轨迹角与路径总长推算
func get_fall_start_offset() -> Vector2:
	var fall_angle: float = deg2rad(FALL_ANGLE_DEGREES)
	return Vector2(cos(fall_angle), -sin(fall_angle)) * FALL_DISTANCE


# 由武器脚本在加入场景树之前调用
func init(target_pos: Vector2, exploding_effect: ExplodingEffect, explode_args: WeaponServiceExplodeArgs) -> void:
	_target_pos = target_pos
	_exploding_effect = exploding_effect
	_explode_args = explode_args


func _ready() -> void:
	_start_pos = _target_pos + get_fall_start_offset()
	global_position = _start_pos
	# 不设置 rotation：全程保持材质自身方向


func _process(delta: float) -> void:
	if _landed:
		return

	_elapsed += delta
	var t: float = clamp(_elapsed / FALL_DURATION, 0.0, 1.0)

	# 加速下落（t² 曲线）；全程保持材质自身方向（不旋转）
	global_position = _start_pos.linear_interpolate(_target_pos, t * t)

	if t >= 1.0:
		_land()


# 落地：在落点生成爆炸并把爆炸交给武器接线
func _land() -> void:
	_landed = true
	set_process(false)
	global_position = _target_pos

	# 缺少爆炸配置时静默自毁
	if _exploding_effect == null or _explode_args == null:
		queue_free()
		return

	var explosion = WeaponService.explode(_exploding_effect, _explode_args)
	if explosion != null:
		emit_signal("explosion_created", explosion)

	queue_free()
