extends Node2D


# 面向迷雾波光照系统的信号：雾视图据此把火灯在 0.25 秒内淡出回收
signal stop_emitting(burning_particles)


# ============================================================
# 火圈：爆炸落点留下的持续燃烧地带
#   盘底是一片 50% 透明的火色圆盘（半径＝真实点燃范围），
#   盘面遍布火焰粒子；敌人进盘当帧即被点燃，之后按间隔持续刷新；
#   自身不造成任何直接伤害；整体透明度吃「爆炸透明度」设置；持续时间结束后渐灭并回收。
#   迷雾波下向雾视图注册一盏火灯（非迷雾波为空操作）。
#   用法：load 场景 → add_child → init_fire(...)
# ============================================================

const FIRE_PARTICLES_SCENE_PATH = "res://particles/burning/torch_burning_particles.tscn"
const ENEMY_MASK = Utils.ENEMIES_BIT
const PARTICLE_BASE_RADIUS = 70.0
const PARTICLE_SPREAD_RATIO = 0.9
const FADE_TIME = 1.0
const LAYER_COLOR = Color(1.0, 0.45, 0.15, 0.5)

var burning_data: BurningData = null
var player_index: int = - 1

var _particles := []
var _light_registered: bool = false
var _radius: float = 0.0
var _fade_tween: Tween = null

onready var _zone: Area2D = $Zone
onready var _collision: CollisionShape2D = $Zone / CollisionShape2D
onready var _particles_root: Node2D = $Particles
onready var _tick_timer: Timer = $TickTimer
onready var _life_timer: Timer = $LifeTimer
onready var _fade_timer: Timer = $FadeTimer


# 初始化火圈：点燃数据、玩家归属、半径、持续时间、点燃间隔与粒子数量
func init_fire(p_burning_data: BurningData, p_player_index: int, radius: float, duration: float, tick_interval: float, particle_count: int) -> void :
	burning_data = p_burning_data
	player_index = p_player_index
	_radius = max(1.0, radius)

	# 与爆炸一致：整体透明度吃「爆炸透明度」设置（盘底与粒子一起生效）
	modulate.a = ProgressData.settings.explosion_opacity

	# 按半径重建碰撞形状（新建形状，避免污染场景里的共享资源）
	var shape := CircleShape2D.new()
	shape.radius = _radius
	_collision.shape = shape

	# 只检测敌人（RigidBody2D 单位），避免影响玩家
	_zone.collision_layer = 0
	_zone.collision_mask = ENEMY_MASK
	_zone.monitorable = false
	_zone.monitoring = true

	# 盘底半径已确定，重绘火色圆盘
	update()

	# 圈内散布火焰粒子
	_spawn_particles(_radius, particle_count)

	# 迷雾波照明
	_register_light()

	_tick_timer.wait_time = max(0.05, tick_interval)
	_tick_timer.start()
	_life_timer.wait_time = max(0.1, duration)
	_life_timer.start()


# 盘底：50% 透明的火色圆盘（半径即点燃范围，随各阶爆炸范围变化）
func _draw() -> void :
	if _radius > 0.0:
		draw_circle(Vector2.ZERO, _radius, LAYER_COLOR)


# 圈内随机散布火焰粒子，整体按半径缩放
func _spawn_particles(radius: float, particle_count: int) -> void :
	var particles_scene = load(FIRE_PARTICLES_SCENE_PATH)
	if particles_scene == null:
		return

	var scale_factor: float = clamp(radius / PARTICLE_BASE_RADIUS, 0.5, 3.0)
	for _i in max(1, particle_count):
		var particle = particles_scene.instance()
		var offset_angle: float = rand_range( - PI, PI)
		var offset_dist: float = rand_range(0.0, max(0.0, radius * PARTICLE_SPREAD_RATIO))
		particle.position = Vector2(cos(offset_angle), sin(offset_angle)) * offset_dist
		particle.scale = Vector2(scale_factor, scale_factor)
		_particles_root.add_child(particle)
		if particle is CPUParticles2D:
			particle.emitting = true
		_particles.append(particle)


# 每个点燃间隔：点燃当前圈内的全部敌人
func _on_TickTimer_timeout() -> void :
	for body in _zone.get_overlapping_bodies():
		_burn_enemy(body)


# 点燃单个敌人（进盘信号与间隔轮询共用）：先过概率与「可点燃」开关，再施加点燃（不造成直接伤害）
func _burn_enemy(body: Node) -> void :
	if not is_instance_valid(body) or body.dead or not body.has_method("apply_burning"):
		return

	# 被魅惑的友方敌人不吃自己的火（未魅惑时返回 -1）
	if body.has_method("get_charmed_by_player_index") and body.get_charmed_by_player_index() >= 0:
		return

	# 无燃烧数据或关闭点燃时跳过
	if burning_data == null or RunData.get_player_effect(Keys.can_burn_enemies_hash, player_index) <= 0:
		return

	# 与命中点燃一致：每次间隔各自判定一次概率
	if not Utils.get_chance_success(burning_data.chance):
		return

	# 重复点燃只会刷新燃烧（apply_burning 内部取最大值）；离开火圈后按原版规则烧完剩余跳数
	body.apply_burning(burning_data)


# 迷雾波照明：向雾视图注册一盏火灯（雾视图每帧按本节点 global_position 跟随）
func _register_light() -> void :
	var main = Utils.get_scene_node()
	if main == null or not main.has_method("_on_emit_fire_particle"):
		return

	_light_registered = true
	main._on_emit_fire_particle(self)


# 熄灯：雾视图收到信号后 0.25 秒内淡出并回收（未注册或已发过则跳过）
func _stop_light() -> void :
	if not _light_registered:
		return

	_light_registered = false
	emit_signal("stop_emitting", self)


# 渐灭：1 秒内把盘底与粒子整体淡出（Tween 作为子节点，随火圈一起回收）
func _fade_out() -> void :
	_fade_tween = Tween.new()
	add_child(_fade_tween)
	_fade_tween.interpolate_property(self, "modulate:a", modulate.a, 0.0, FADE_TIME)
	_fade_tween.start()


# 持续时间结束：停止点燃并进入渐灭
func _on_LifeTimer_timeout() -> void :
	_tick_timer.stop()
	_zone.monitoring = false
	_stop_light()
	_fade_out()
	for particle in _particles:
		if is_instance_valid(particle):
			particle.emitting = false
	_fade_timer.wait_time = FADE_TIME
	_fade_timer.start()


func _on_FadeTimer_timeout() -> void :
	queue_free()


func _exit_tree() -> void :
	# 兜底：火圈被波次清理直接回收时也要熄灯，避免雾视图残留失效节点
	_stop_light()