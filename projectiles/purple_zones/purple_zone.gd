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
# 玩家子弹层（player_projectile.tscn 的 Hitbox.collision_layer = 8）
const BULLET_MASK = 8
# 盘底默认颜色（鬼火少年的紫）；橡皮擦用 set_layer_color() 覆盖为黑
var layer_color = Color(0.62, 0.28, 1.0, 0.20)
# 每名玩家的伤害闸门：密集叠片时同一玩家会同时落在多片圈里，
# 不设闸门会让 DPS 成倍膨胀；闸门时间内只结算一次，保证总伤害与「一片一片」时一致。
const DAMAGE_GATE = 0.5
const GATE_META = "guihuo_zone_next_hit"

var damage: int = 1

var _radius: float = 40.0
var _fade_tween: Tween = null
# 常驻（不随时间消失，等本体死亡/离场时由 trail 调 release()）
var _persistent: bool = false
# 是否拦截玩家子弹
var _block_bullets: bool = false
var _bullet_blocker: Area2D = null
var _released: bool = false

onready var _zone: Area2D = $Zone
onready var _collision: CollisionShape2D = $Zone / CollisionShape2D
onready var _tick_timer: Timer = $TickTimer
onready var _life_timer: Timer = $LifeTimer
onready var _fade_timer: Timer = $FadeTimer


func _ready() -> void :
	# 归组：便于探针/调试统计存活片数
	add_to_group("guihuo_purple_zone")


# 初始化紫区：伤害、半径、持续时间、结算间隔
#   p_damage <= 0 ⇒ 无害区（橡皮擦的黑区）：只做视觉 + 擦弹，不建伤害结算
func init_zone(p_damage: int, radius: float, duration: float, tick_interval: float) -> void :
	damage = max(0, p_damage)
	_radius = max(1.0, radius)

	# 与爆炸一致：整体透明度吃「爆炸透明度」设置
	modulate.a = ProgressData.settings.explosion_opacity

	# 按半径重建碰撞形状（新建形状，避免污染场景里的共享资源）
	var shape := CircleShape2D.new()
	shape.radius = _radius
	_collision.shape = shape

	# 只检测玩家（player.tscn 的 collision_layer = 2），不影响敌人与中立；
	# 无害区（damage <= 0）不检测、不结算（连 0 伤害的受击动画/无敌帧都不触发）
	_zone.collision_layer = 0
	_zone.collision_mask = PLAYER_MASK if damage > 0 else 0
	_zone.monitorable = false
	_zone.monitoring = damage > 0

	update()

	if damage > 0:
		_tick_timer.wait_time = max(0.05, tick_interval)
		_tick_timer.start()
	else:
		_tick_timer.stop()

	# duration <= 0 ⇒ 常驻区域：不启动寿命计时，等本体死亡/离场时由 trail 调 release()
	if duration <= 0.0:
		_persistent = true
		_life_timer.stop()
	else:
		_life_timer.wait_time = max(0.1, duration)
		_life_timer.start()


# 盘底：半透明紫色圆盘（半径即伤害范围）
func _draw() -> void :
	if _radius > 0.0:
		draw_circle(Vector2.ZERO, _radius, layer_color)


# 每个结算间隔：伤害当前圈内的全部玩家
func _on_TickTimer_timeout() -> void :
	for body in _zone.get_overlapping_bodies():
		_damage_target(body)


# 对单个玩家结算一次伤害（与敌人攻击同链路：TakeDamageArgs + take_damage）
func _damage_target(body: Node) -> void :
	if damage <= 0:
		return
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


# 覆盖盘底颜色（橡皮擦传黑色）
func set_layer_color(color: Color) -> void :
	layer_color = color
	update()


# 拦截玩家子弹：圈内的玩家弹体（layer 8）一律回收（穿透弹也一并擦掉）
func set_bullet_blocking(p_enabled: bool) -> void :
	_block_bullets = p_enabled

	if p_enabled:
		_setup_bullet_blocker()
	elif _bullet_blocker != null:
		_bullet_blocker.queue_free()
		_bullet_blocker = null


func _setup_bullet_blocker() -> void :
	if _bullet_blocker != null:
		return

	var blocker := Area2D.new()
	blocker.collision_layer = 0
	blocker.collision_mask = BULLET_MASK
	blocker.monitorable = false
	blocker.monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	blocker.add_child(shape)

	add_child(blocker)
	var _error = blocker.connect("area_entered", self, "_on_bullet_entered")
	_bullet_blocker = blocker


# 玩家弹体进圈：直接回收（弹体走对象池 ⇒ 必须用 stop()，不能 queue_free）
func _on_bullet_entered(area: Area2D) -> void :
	if area == null or not is_instance_valid(area):
		return

	var projectile = area.get_parent()
	if projectile != null and projectile.has_method("stop"):
		projectile.stop()


# 释放：常驻区域在橡皮擦死亡/离场时由 trail 调用（等同寿命到点）
func release() -> void :
	if _released:
		return
	_released = true
	_on_LifeTimer_timeout()


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
