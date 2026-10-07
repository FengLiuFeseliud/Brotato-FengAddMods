extends Node2D

# ============================================================
# 紫区：鬼火少年冲刺后留下的持续伤害地带
#   盘底是一片半透明紫色圆盘（半径＝真实伤害范围）；
#   每 tick_interval 秒对圈内玩家结算一次直接伤害（走 TakeDamageArgs + take_damage，与敌人攻击同链路）；
#   持续时间结束后渐灭并回收。
#   用法：load 场景 → add_child → init_zone(...)
# ============================================================

const PLAYER_MASK = 2
const FADE_TIME = 0.5
# 盘底透明度：密集叠片（间距 45、相叠约 1 倍）下用低透明度，叠起来才是均匀紫带而不是深色斑
const LAYER_COLOR = Color(0.62, 0.28, 1.0, 0.20)
# 每名玩家的伤害闸门：密集叠片时同一玩家会同时落在多片圈里，
# 不设闸门会让 DPS 成倍膨胀；闸门时间内只结算一次，保证总伤害与「一片一片」时一致。
const DAMAGE_GATE = 0.5
const GATE_META = "guihuo_zone_next_hit"

var damage: int = 1

var _radius: float = 40.0
var _fade_tween: Tween = null

onready var _zone: Area2D = $Zone
onready var _collision: CollisionShape2D = $Zone / CollisionShape2D
onready var _tick_timer: Timer = $TickTimer
onready var _life_timer: Timer = $LifeTimer
onready var _fade_timer: Timer = $FadeTimer


func _ready() -> void :
	# 归组：便于探针/调试统计存活片数
	add_to_group("guihuo_purple_zone")


# 初始化紫区：伤害、半径、持续时间、结算间隔
func init_zone(p_damage: int, radius: float, duration: float, tick_interval: float) -> void :
	damage = max(1, p_damage)
	_radius = max(1.0, radius)

	# 与爆炸一致：整体透明度吃「爆炸透明度」设置
	modulate.a = ProgressData.settings.explosion_opacity

	# 按半径重建碰撞形状（新建形状，避免污染场景里的共享资源）
	var shape := CircleShape2D.new()
	shape.radius = _radius
	_collision.shape = shape

	# 只检测玩家（player.tscn 的 collision_layer = 2），不影响敌人与中立
	_zone.collision_layer = 0
	_zone.collision_mask = PLAYER_MASK
	_zone.monitorable = false
	_zone.monitoring = true

	update()

	_tick_timer.wait_time = max(0.05, tick_interval)
	_tick_timer.start()
	_life_timer.wait_time = max(0.1, duration)
	_life_timer.start()


# 盘底：半透明紫色圆盘（半径即伤害范围）
func _draw() -> void :
	if _radius > 0.0:
		draw_circle(Vector2.ZERO, _radius, LAYER_COLOR)


# 每个结算间隔：伤害当前圈内的全部玩家
func _on_TickTimer_timeout() -> void :
	for body in _zone.get_overlapping_bodies():
		_damage_target(body)


# 对单个玩家结算一次伤害（与敌人攻击同链路：TakeDamageArgs + take_damage）
func _damage_target(body: Node) -> void :
	if not is_instance_valid(body) or not body.has_method("take_damage"):
		return
	if body.get("dead") == true:
		return

	# 伤害闸门：同一玩家在闸门时间内只被结算一次（时间戳存在玩家自己身上，联机互不影响）
	var now: float = OS.get_ticks_msec() / 1000.0
	if body.has_meta(GATE_META) and now < float(body.get_meta(GATE_META)):
		return
	body.set_meta(GATE_META, now + DAMAGE_GATE)

	var args = TakeDamageArgs.new( - 1, null)
	args.from = self
	body.take_damage(damage, args)


# 渐灭：把盘底整体淡出（Tween 作为子节点，随紫区一起回收）
func _fade_out() -> void :
	_fade_tween = Tween.new()
	add_child(_fade_tween)
	_fade_tween.interpolate_property(self, "modulate:a", modulate.a, 0.0, FADE_TIME)
	_fade_tween.start()


# 持续时间结束：停止结算并进入渐灭
func _on_LifeTimer_timeout() -> void :
	_tick_timer.stop()
	_zone.monitoring = false
	_fade_out()
	_fade_timer.wait_time = FADE_TIME
	_fade_timer.start()


func _on_FadeTimer_timeout() -> void :
	queue_free()
