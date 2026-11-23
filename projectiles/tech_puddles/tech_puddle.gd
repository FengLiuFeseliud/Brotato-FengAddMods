extends Node2D


# ============================================================
# 科技水枪泥潭：玩家侧区域
#   酸液模式：每 tick 对圈内敌人造成伤害
#   机械模式：进入圈内的敌人减速一次（持续 slow_hold）
#   视觉复用原版 puddle 贴图，用 modulate 染绿 / 染灰
# ============================================================


enum Mode { ACID, SLOW }

const ENEMY_MASK: = 4
const FADE_TIME: = 0.5

var mode: int = Mode.ACID
var damage: = 1
var slow_percent: = 30.0
var slow_hold: = 3.0
var player_index: = - 1
var weapon = null

var _slowed: = {}
var _fade_tween: Tween = null

onready var _sprite: Sprite = $Sprite
onready var _outline: Sprite = $Outline
onready var _zone: Area2D = $Zone
onready var _collision: CollisionShape2D = $Zone / CollisionShape2D
onready var _tick_timer: Timer = $TickTimer
onready var _life_timer: Timer = $LifeTimer
onready var _fade_timer: Timer = $FadeTimer


# p_mode 使用与武器脚本一致的 0=酸液 / 1=机械
func init_puddle(p_mode: int, p_damage: int, p_player_index: int, radius: float, duration: float, tick_interval: float, p_slow_percent: float, p_slow_hold: float, p_weapon = null) -> void :
	mode = p_mode
	damage = max(1, p_damage)
	player_index = p_player_index
	slow_percent = p_slow_percent
	slow_hold = p_slow_hold
	weapon = p_weapon

	var shape: = CircleShape2D.new()
	shape.radius = max(1.0, radius)
	_collision.shape = shape

	_zone.collision_layer = 0
	_zone.collision_mask = ENEMY_MASK
	_zone.monitorable = false
	_zone.monitoring = true

	var sprite_scale: float = max(0.1, radius / 60.0)
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_outline.scale = Vector2(sprite_scale, sprite_scale)

	if mode == Mode.ACID:
		_sprite.modulate = Color(0.55, 1.0, 0.35, 0.55)
		_outline.modulate = Color(0.12, 0.3, 0.08, 0.85)
		_tick_timer.wait_time = max(0.05, tick_interval)
		_tick_timer.start()
	else:
		_sprite.modulate = Color(0.68, 0.68, 0.68, 0.55)
		_outline.modulate = Color(0.18, 0.18, 0.18, 0.85)
		_tick_timer.stop()

	_life_timer.one_shot = true
	_fade_timer.one_shot = true
	_life_timer.wait_time = max(0.1, duration)
	_life_timer.start()


func _physics_process(_delta: float) -> void :
	if mode != Mode.SLOW:
		return

	for body in _zone.get_overlapping_bodies():
		if _slowed.has(body):
			continue
		if not is_instance_valid(body) or body.get("dead") == true:
			continue
		if body.get("_is_charmed") == true:
			continue
		if not body.has_method("add_decaying_speed"):
			continue

		_slowed[body] = true
		var stats = body.get("current_stats")
		var speed: float = stats.speed if stats != null else 0.0
		body.add_decaying_speed( - int(speed * slow_percent / 100.0), true, slow_hold)


func _on_TickTimer_timeout() -> void :
	if mode != Mode.ACID:
		return

	for body in _zone.get_overlapping_bodies():
		_damage_enemy(body)


func _damage_enemy(body: Node) -> void :
	if not is_instance_valid(body) or body.get("dead") == true:
		return
	if body.get("_is_charmed") == true:
		return
	if not body.has_method("take_damage"):
		return

	var args: = TakeDamageArgs.new(player_index)
	args.armor_applied = true
	args.dodgeable = false
	args.is_burning = false

	var main = Utils.get_scene_node()
	if main != null and "_players" in main and player_index >= 0 and player_index < main._players.size():
		args.from = main._players[player_index]

	var dmg_taken = body.take_damage(damage, args)
	var damage_dealt: int = 0
	if dmg_taken is Array and dmg_taken.size() > 1:
		damage_dealt = int(dmg_taken[1])
	if damage_dealt > 0 and weapon != null and is_instance_valid(weapon) and weapon.has_method("on_weapon_hit_something"):
		weapon.on_weapon_hit_something(body, damage_dealt, null)


func _on_LifeTimer_timeout() -> void :
	_tick_timer.stop()
	_zone.monitoring = false
	_fade_out()
	_fade_timer.wait_time = FADE_TIME
	_fade_timer.start()


func _fade_out() -> void :
	_fade_tween = Tween.new()
	add_child(_fade_tween)
	_fade_tween.interpolate_property(self, "modulate:a", modulate.a, 0.0, FADE_TIME)
	_fade_tween.start()


func _on_FadeTimer_timeout() -> void :
	queue_free()
