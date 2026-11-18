class_name BlackHoleDevice
extends Structure


# ============================================================
# 黑洞装置（由「黑洞发生器」武器按炮台式召唤：每波开场在场地中心 200 半径内随机 1 个）
#   出现时显示半透明大白圆（半径 = max_range（300 + 构筑物射程））
#   3 秒内（受构筑物攻速缩短）缩小到 15% 并把透明度降到 0 → 爆炸（结算一次黑洞伤害）
#   → 生成黑洞构筑物 → 装置自毁
# ============================================================

const BLACK_HOLE_SCRIPT = preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/structures/black_hole/black_hole.gd")
const BLACK_HOLE_SCENE = preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/structures/black_hole/black_hole.tscn")
const EXPLOSION_SCENE = preload("res://projectiles/explosion.tscn")
# explosion.tscn 命中圆基准半径
const EXPLOSION_BASE_RADIUS := 147.34
# 白圆贴图半径（black_hole_warning.png 256x256）
const WARNING_TEXTURE_RADIUS := 128.0
# 蓄力时长（秒，受构筑物攻速缩短）/ 缩小到的最小比例 / 起始与结束透明度（越缩越不透明）
const CHARGE_TIME := 3.0
const MIN_SCALE_FACTOR := 0.0
const START_ALPHA := 0.2
const END_ALPHA := 1.0
const EXPLOSION_SMOKE := 24
const EXPLOSION_DB := -8

onready var _warning: Sprite = $WarningCircle

var _charge_time: float = 0.0
var _charge_duration: float = CHARGE_TIME
var _device_data: Resource = null
var _finished: bool = false


func set_data(data: Resource) -> void:
	.set_data(data)

	_device_data = data

	# 蓄力时长吃构筑物攻速：3 秒 = 180 帧，+50% 攻速 → 120 帧 = 2 秒
	var charge_frames: int = int(CHARGE_TIME * 60.0)
	if player_index >= 0:
		charge_frames = WeaponService.apply_structure_attack_speed_effects(charge_frames, player_index)
	_charge_duration = max(0.05, float(charge_frames) / 60.0)

	_charge_time = 0.0
	_finished = false
	_apply_warning_visual(0.0)


# 白圆半径 = 构筑物面板 max_range（300 + 构筑物射程）
func get_warning_radius() -> float:
	var base_radius: float = float(stats.max_range) if stats != null else 100.0
	return max(1.0, base_radius)


# t: 0 -> 1（1 = 缩到最小且完全透明）
func _apply_warning_visual(t: float) -> void:
	if _warning == null:
		return

	var progress: float = clamp(t, 0.0, 1.0)
	var scale_factor: float = get_warning_radius() / WARNING_TEXTURE_RADIUS
	var grow: float = lerp(1.0, MIN_SCALE_FACTOR, progress)
	_warning.scale = Vector2(scale_factor * grow, scale_factor * grow)
	_warning.modulate = Color(1, 1, 1, lerp(START_ALPHA, END_ALPHA, progress))


func _physics_process(delta: float) -> void:
	if dead or _finished:
		return

	_charge_time += delta
	var t: float = clamp(_charge_time / max(0.01, _charge_duration), 0.0, 1.0)
	_apply_warning_visual(t)

	if t >= 1.0:
		_finish()


func _finish() -> void:
	if _finished:
		return

	_finished = true
	_explode()
	_spawn_black_hole()
	die()


# 爆炸：对黑洞半径内敌人结算一次黑洞伤害
func _explode() -> void:
	var radius: float = get_warning_radius()

	var effect := ExplodingEffect.new()
	effect.explosion_scene = EXPLOSION_SCENE
	effect.scale = radius / EXPLOSION_BASE_RADIUS
	effect.base_smoke_amount = EXPLOSION_SMOKE
	effect.sound_db_mod = EXPLOSION_DB

	var args := WeaponServiceExplodeArgs.new()
	args.pos = global_position
	args.from_player_index = player_index
	args.from = self
	args.damage_tracking_key_hash = Keys.generate_hash(BLACK_HOLE_SCRIPT.DAMAGE_TRACKING_KEY)

	if stats != null:
		args.damage = int(stats.damage)
		args.scaling_stats = stats.scaling_stats
		args.accuracy = stats.accuracy
		args.crit_chance = stats.crit_chance
		args.crit_damage = stats.crit_damage
		args.burning_data = stats.burning_data
	else:
		args.damage = 0

	WeaponService.explode(effect, args)


# 生成黑洞构筑物（把装置拿到的效果数据透传过去）
func _spawn_black_hole() -> void:
	var main = Utils.get_scene_node()
	if main == null or not ("_entity_spawner" in main) or main._entity_spawner == null:
		return
	if player_index < 0:
		return

	var queue = main._entity_spawner.queues_to_spawn_structures[player_index]
	var request := SpawnRequest.new(EntityType.STRUCTURE, BLACK_HOLE_SCENE, global_position)
	request.data = _device_data
	queue.push_back(request)

# 与 clean_up_room 的重复 die 调用兼容（已死时直接返回，避免 Structure.die 的 assert）
func die(args = Utils.default_die_args) -> void:
	if dead:
		return

	.die(args)
