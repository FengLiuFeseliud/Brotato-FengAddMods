extends Node2D

export (PackedScene) var puddle_scene
export (PackedScene) var rain_particles_scene
export (Array, Texture) var puddle_textures = []
export (Texture) var rain_drop_texture
export (float) var puddle_lifetime = 10.0
export (int) var max_active_puddles = 30
export (float) var spawn_interval = 0.25
export (float) var puddle_scale_min = 1.0
export (float) var puddle_scale_max = 3.0

var _main: Main
var _rain_particles: CPUParticles2D
var _spawn_timer: Timer
var _active_puddles: Array = []


func _ready() -> void:
	_main = Utils.get_scene_node() as Main

	if puddle_textures == null or puddle_textures.size() == 0:
		ModLoaderLog.error("Rain event has no puddle textures assigned", "FengAddMods")

	_spawn_rain()

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = max(0.05, spawn_interval)
	_spawn_timer.one_shot = false
	_spawn_timer.connect("timeout", self, "_on_spawn_timer_timeout")
	add_child(_spawn_timer)
	_spawn_timer.start()

	# 开局先撒一批，避免前 5 秒完全没有水洼
	for _i in range(5):
		_try_spawn_puddle()


func _exit_tree() -> void:
	if is_instance_valid(_rain_particles):
		_rain_particles.queue_free()


func _on_spawn_timer_timeout() -> void:
	_clean_invalid_puddles()
	_try_spawn_puddle()


func _clean_invalid_puddles() -> void:
	for i in range(_active_puddles.size() - 1, -1, -1):
		if not is_instance_valid(_active_puddles[i]):
			_active_puddles.remove(i)


func _try_spawn_puddle() -> void:
	if puddle_scene == null:
		return
	if puddle_textures == null or puddle_textures.size() == 0:
		return

	_clean_invalid_puddles()

	if _active_puddles.size() >= max_active_puddles:
		return

	var texture: Texture = Utils.get_rand_element(puddle_textures)
	if texture == null:
		return

	var p_scale = rand_range(puddle_scale_min, puddle_scale_max)
	var half_size = texture.get_size() * p_scale * 0.5
	var edge = int(max(half_size.x, half_size.y)) + 24

	# 全图随机位置；尽量不直接压在玩家脚下
	var pos = ZoneService.get_rand_pos(edge)
	for _i in range(5):
		if _is_far_from_players(pos):
			break
		pos = ZoneService.get_rand_pos(edge)

	var puddle = puddle_scene.instance()
	puddle.setup(texture, p_scale, puddle_lifetime)
	puddle.position = pos
	puddle.rotation = rand_range(0, TAU)
	add_child(puddle)

	_active_puddles.push_back(puddle)


func _is_far_from_players(pos: Vector2) -> bool:
	if _main == null:
		return true

	for player in _main._players:
		if is_instance_valid(player) and player.global_position.distance_to(pos) < 120.0:
			return false

	return true


func _spawn_rain() -> void:
	if _main == null or _main._camera == null:
		return

	if rain_particles_scene == null or rain_drop_texture == null:
		ModLoaderLog.error(
			"Rain event is missing rain particles scene or rain drop texture",
			"FengAddMods"
		)
		return

	_rain_particles = rain_particles_scene.instance()
	_rain_particles.texture = rain_drop_texture
	_main._camera.add_child(_rain_particles)
	_rain_particles.position = Vector2.ZERO
