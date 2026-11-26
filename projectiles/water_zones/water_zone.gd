extends Node2D


# ============================================================
# 效果：水洼圈（水球爆炸 / 雨事件共用的独立水洼）
#   盘底是水洼贴图（半径由 init_water 指定），圈内：
#     - 玩家：进入即打滑（与雨事件水洼一致），离开或水洼消失时撤销
#     - 敌人：进入立即潮湿，之后按 wet_tick_interval 刷新，持续 wet_duration 秒
#   不造成任何伤害、不点燃；持续时间结束后淡出并回收。
#   用法：instance → init_water(...) → add_child（形状必须在入树前设置，否则物理区不刷新）
# ============================================================

const PUDDLE_TEXTURE_PATHS := [
	"res://mods-unpacked/FengLiu-FengAddMods/zone_events/events/rain/textures/puddle_1.png",
	"res://mods-unpacked/FengLiu-FengAddMods/zone_events/events/rain/textures/puddle_2.png",
	"res://mods-unpacked/FengLiu-FengAddMods/zone_events/events/rain/textures/puddle_3.png",
	"res://mods-unpacked/FengLiu-FengAddMods/zone_events/events/rain/textures/puddle_4.png",
	"res://mods-unpacked/FengLiu-FengAddMods/zone_events/events/rain/textures/puddle_5.png",
]
const PLAYER_MASK = Utils.PLAYER_BIT
const ENEMY_MASK = Utils.ENEMIES_BIT
const FADE_TIME = 1.0

var wet_duration: float = 2.0
var wet_tick_interval: float = 0.5

var _radius: float = 0.0
var _duration: float = 1.0
var _initialized := false
var _timers_started := false
var _slippery_bodies: Array = []
var _fade_tween: Tween = null


# 初始化水洼：半径、持续时间、潮湿时长、刷新间隔、指定贴图（null 则随机）、整体透明度
func init_water(radius: float, duration: float, p_wet_duration: float = 2.0, p_wet_tick_interval: float = 0.5, texture: Texture = null, opacity: float = 1.0) -> void :
	_initialized = true
	_radius = max(1.0, radius)
	_duration = max(0.1, duration)
	wet_duration = max(0.0, p_wet_duration)
	wet_tick_interval = max(0.05, p_wet_tick_interval)

	modulate.a = clamp(opacity, 0.0, 1.0)

	var zone: Area2D = get_node("Zone")
	var collision: CollisionShape2D = get_node("Zone/CollisionShape2D")
	var sprite: Sprite = get_node("Sprite")

	# 按半径重建碰撞形状（圆形，与火圈一致）；形状必须在入树前设置，物理区才会按新半径注册
	var shape := CircleShape2D.new()
	shape.radius = _radius
	collision.shape = shape

	# 同时检测玩家（打滑）与敌人（潮湿）
	zone.collision_layer = 0
	zone.collision_mask = PLAYER_MASK | ENEMY_MASK
	zone.monitoring = true

	var texture_to_use: Texture = texture
	if texture_to_use == null:
		texture_to_use = _get_random_puddle_texture()

	if texture_to_use != null:
		sprite.texture = texture_to_use
		var texture_width: float = max(1.0, texture_to_use.get_width())
		var sprite_scale: float = _radius * 2.0 / texture_width
		sprite.scale = Vector2(sprite_scale, sprite_scale)
		sprite.rotation = rand_range(0.0, TAU)

	if is_inside_tree():
		_start_timers()


func _ready() -> void :
	if _initialized:
		_start_timers()


# 启动计时器（入树后执行；离树调用 init 时延后到这里）
func _start_timers() -> void :
	if _timers_started:
		return
	_timers_started = true

	var tick_timer: Timer = get_node("TickTimer")
	tick_timer.wait_time = wet_tick_interval
	tick_timer.start()

	var life_timer: Timer = get_node("LifeTimer")
	life_timer.wait_time = _duration
	life_timer.start()


# 随机取一张雨事件水洼贴图（已导入，无新增素材）
func _get_random_puddle_texture() -> Texture:
	var textures := []
	for path in PUDDLE_TEXTURE_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var texture = load(path)
		if texture != null:
			textures.push_back(texture)

	if textures.empty():
		return null
	return Utils.get_rand_element(textures)


# 玩家踩入：登记打滑源；敌人踩入：立即潮湿一次
func _on_Zone_body_entered(body) -> void :
	if body == null:
		return

	if body.has_method("fengliu_add_slippery_source"):
		if not _slippery_bodies.has(body):
			_slippery_bodies.push_back(body)
		body.fengliu_add_slippery_source(get_instance_id())

	_wet_enemy(body)


func _on_Zone_body_exited(body) -> void :
	_slippery_bodies.erase(body)
	if body != null and body.has_method("fengliu_remove_slippery_source"):
		body.fengliu_remove_slippery_source(get_instance_id())


# 每 tick：给圈内全部敌人续潮湿
func _on_TickTimer_timeout() -> void :
	if wet_duration <= 0.0:
		return

	var zone: Area2D = get_node("Zone")
	for body in zone.get_overlapping_bodies():
		_wet_enemy(body)


# 潮湿单个敌人（进入信号与间隔轮询共用）
func _wet_enemy(body) -> void :
	if wet_duration <= 0.0 or not is_instance_valid(body):
		return

	if not body.has_method("fengliu_apply_wet"):
		return

	# 统一状态守卫：死亡 / 正在死亡 / 掉落物 / 被魅惑的目标都不处理
	if body.has_method("fengliu_can_get_status") and not body.fengliu_can_get_status():
		return

	body.fengliu_apply_wet(wet_duration)


# 持续时间结束：停 tick、停监测、1 秒淡出
func _on_LifeTimer_timeout() -> void :
	var tick_timer: Timer = get_node("TickTimer")
	tick_timer.stop()

	var zone: Area2D = get_node("Zone")
	zone.monitoring = false

	_fade_tween = Tween.new()
	add_child(_fade_tween)
	_fade_tween.interpolate_property(self, "modulate:a", modulate.a, 0.0, FADE_TIME)
	_fade_tween.start()

	var fade_timer: Timer = get_node("FadeTimer")
	fade_timer.wait_time = FADE_TIME
	fade_timer.start()


func _on_FadeTimer_timeout() -> void :
	queue_free()


func _exit_tree() -> void :
	# 兜底：水洼被波次清理直接回收时也要撤销玩家打滑源
	for body in _slippery_bodies:
		if is_instance_valid(body) and body.has_method("fengliu_remove_slippery_source"):
			body.fengliu_remove_slippery_source(get_instance_id())
	_slippery_bodies.clear()
