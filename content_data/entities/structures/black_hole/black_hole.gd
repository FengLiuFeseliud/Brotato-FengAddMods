class_name BlackHole
extends Structure


# ============================================================
# 构筑物：黑洞（由「黑洞发生器」武器的效果生成）
#   每 stats.cooldown 帧（受建筑攻速影响）对半径内所有敌人：
#     1) 结算面板伤害（stats.damage 5 + 50/75/100/150% 工程学缩放，按档位）
#     2) 朝黑洞中心吸引「武器面板击退」的距离
#   共（10 + 50/75/100/125% 工程学）次后，核心淡出并自毁。
#   半径 = stats.max_range（300 + 构筑物射程）× (1 + 1% × 本黑洞击杀数)
#   视觉：BlackHoleCore（256×256，运行时归一化）按「范围直径」缩放代表范围，绘制在草之上、玩家/敌人之下
# ============================================================

const DAMAGE_TRACKING_KEY := "item_black_hole_generator"
const CORE_FADE_TIME := 0.3
const CORE_TEXTURE_PATH := 'res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/structures/black_hole/black_hole_core.png'
const CORE_TEXTURE_SIZE := 256
const CORE_GROW_SPEED := 250.0
const VISUAL_OFFSET := Vector2(0, 0)
const PLAYER_PULL_RATIO := 1.0
const DEVOUR_ATTACK_BONUS := 3
const DEVOUR_SCAN_INTERVAL := 0.25
const DEFAULT_PULL_DISTANCE := 25.0
# 吸引距离 = 发生器面板击退 × 该倍数
const PULL_DISTANCE_RATIO := 2.0
# 原版击退通道每帧衰减 10%（unit.gd: linear_interpolate(ZERO, 0.1)）⇒ 初始向量 v 的总位移 ≈ v × 10
const KNOCKBACK_DECAY := 0.1
# 抵消击退抗性时除数的下限（防止 0 除/数值爆炸）
const MIN_RESIST_FACTOR := 0.2
const BLACK_HOLE_WEAPON_ID := "weapon_black_hole_generator"
const CLOSE_AFTER_ATTACKS_BASE := 10
const ENGINEERING_ATTACK_RATE := 0.5
const GRASS_STATE_INTERVAL := 0.5
# 每击杀 1 个敌人：本波内黑洞半径 +1%（存 RunData 的玩家 meta，换波自动清零）
const KILL_RANGE_RATE := 0.01
const WAVE_KILLS_META := "fengliu_black_hole_wave_kills"
const WAVE_KILLS_WAVE_META := "fengliu_black_hole_wave_kills_wave"
# 视觉专用层的名字：挂在 main 下、索引固定在 Entities 前一位
# ⇒ 绘制顺序在「草/材料/消耗品/出生标记」之后、「玩家/敌人/黑洞本体/投射物」之前
const VISUAL_LAYER_NAME := "FengliuAuraLayer"

onready var _hole_shape: CollisionShape2D = $HoleArea/CollisionShape2D
onready var _core: Sprite = $BlackHoleCore
onready var _hitbox: Hitbox = $Hitbox

var _core_attached_to_container: bool = false
var _enemies_in_area: Array = []
var _players_in_area: Array = []
var _cooldown: float = 0.0
var _attacks_before_close: int = CLOSE_AFTER_ATTACKS_BASE
var _attacks_done: int = 0
var _finish_time_left: float = -1.0
var _grass_state_time_left: float = 0.0
var _player_pull_cooldown: float = 0.0
var _devoured_damage: int = 0
var _devour_scan_cooldown: float = 0.0
var _close_after_attacks_base: int = CLOSE_AFTER_ATTACKS_BASE
var _engineering_attack_rate: float = ENGINEERING_ATTACK_RATE
var _pull_distance: float = DEFAULT_PULL_DISTANCE
var _core_alpha_target: float = 1.0
var _core_radius_current: float = -1.0
var _core_texture_loaded: bool = false
var _hitbox_args: = Hitbox.HitboxArgs.new()


func set_data(data: Resource) -> void:
	.set_data(data)

	var pull_value = data.get("default_pull_distance") if data != null else null
	_pull_distance = float(pull_value) if pull_value != null else DEFAULT_PULL_DISTANCE
	var base_attacks = data.get("close_after_attacks_base") if data != null else null
	_close_after_attacks_base = int(base_attacks) if base_attacks != null else CLOSE_AFTER_ATTACKS_BASE
	var attack_rate = data.get("engineering_attack_rate") if data != null else null
	_engineering_attack_rate = float(attack_rate) if attack_rate != null else ENGINEERING_ATTACK_RATE

	var engineering: float = Utils.get_stat(Keys.stat_engineering_hash, player_index) if player_index >= 0 else 0.0
	_attacks_before_close = int(max(1, _close_after_attacks_base + int(engineering * _engineering_attack_rate)))

	_apply_area_shape(true)
	_attach_core_to_layer()
	_apply_core_texture()
	_apply_hitbox_stats()

	_hitbox.damage_tracking_key_hash = Keys.generate_hash(DAMAGE_TRACKING_KEY)
	_hitbox.from = self

	# 击杀计数：本波累计（换波自动归零），新召唤的黑洞沿用本波已累计的值
	if not _hitbox.is_connected("killed_something", self, "_on_hitbox_killed_something"):
		_hitbox.connect("killed_something", self, "_on_hitbox_killed_something")

	_attacks_done = 0
	_finish_time_left = -1.0
	_set_area_closed(false, true)
	_cooldown = 0.0


# 黑洞判定半径 = stats.max_range（300 + 构筑物射程）× (1 + 1% × 本波累计击杀数)
func get_black_hole_radius() -> float:
	var base_radius: float = float(stats.max_range) if stats != null else 100.0
	return max(1.0, base_radius) * (1.0 + KILL_RANGE_RATE * float(get_kill_count()))


# 本波累计击杀数（存在 RunData.players_data[i] 的 meta 上，换波自动归零）
func get_kill_count() -> int:
	if player_index < 0 or RunData.players_data.size() <= player_index:
		return 0

	var prd = RunData.players_data[player_index]
	if prd == null:
		return 0

	var wave_meta = prd.get_meta(WAVE_KILLS_WAVE_META)
	if wave_meta == null or int(wave_meta) != RunData.current_wave:
		return 0

	var kills_meta = prd.get_meta(WAVE_KILLS_META)
	if kills_meta == null:
		return 0

	return int(kills_meta)


# 记一次击杀（跨波自动重置计数）
func _add_wave_kill() -> void:
	if player_index < 0 or RunData.players_data.size() <= player_index:
		return

	var prd = RunData.players_data[player_index]
	if prd == null:
		return

	var wave_meta = prd.get_meta(WAVE_KILLS_WAVE_META)
	if wave_meta == null or int(wave_meta) != RunData.current_wave:
		prd.set_meta(WAVE_KILLS_WAVE_META, RunData.current_wave)
		prd.set_meta(WAVE_KILLS_META, 0)

	var kills_meta = prd.get_meta(WAVE_KILLS_META)
	var kills: int = int(kills_meta) if kills_meta != null else 0
	prd.set_meta(WAVE_KILLS_META, kills + 1)


# 击杀即时放大判定圆与本体（本波内持续生效）
func _on_hitbox_killed_something(_thing_killed) -> void:
	if dead:
		return

	_add_wave_kill()
	_apply_area_shape()


func _apply_area_shape(instant: bool = false) -> void:
	var radius: float = get_black_hole_radius()

	_hole_shape.shape.radius = radius
	if _core == null:
		return

	if instant or _core_radius_current < 0.0:
		_core_radius_current = radius
		_apply_core_scale()


func _apply_core_scale() -> void:
	if _core == null or _core_radius_current < 0.0:
		return

	var tex_width: float = float(CORE_TEXTURE_SIZE)
	if _core.texture != null:
		tex_width = max(1.0, float(_core.texture.get_width()))

	var scale_factor: float = (_core_radius_current * 2.0) / tex_width
	_core.scale = Vector2(scale_factor, scale_factor)


func _update_core_scale(delta: float) -> void:
	if _core == null:
		return

	var target: float = get_black_hole_radius()
	if _core_radius_current < 0.0:
		_core_radius_current = target

	_core_radius_current = move_toward(_core_radius_current, target, CORE_GROW_SPEED * delta)
	_apply_core_scale()

	if _core_attached_to_container:
		_core.global_position = global_position + VISUAL_OFFSET


func _apply_hitbox_stats() -> void:
	if stats == null:
		return

	_hitbox_args.set_from_weapon_stats(stats)
	_hitbox.effect_scale = stats.effect_scale
	_hitbox.from = self
	_hitbox.set_damage(stats.damage + _devoured_damage, _hitbox_args)
	_hitbox.speed_percent_modifier = stats.speed_percent_modifier
	_hitbox.set_knockback(Vector2.ZERO, 0, 0)


func _on_HoleArea_body_entered(body: Node) -> void:
	if body is Enemy:
		if not _enemies_in_area.has(body):
			_enemies_in_area.append(body)
	elif body is Player:
		if not _players_in_area.has(body):
			_players_in_area.append(body)


func _on_HoleArea_body_exited(body: Node) -> void:
	_enemies_in_area.erase(body)
	_players_in_area.erase(body)


func _physics_process(delta: float) -> void:
	_update_core_fade(delta)
	_update_core_scale(delta)
	_update_grass_state(delta)

	if dead or stats == null:
		return

	# 用完：核心淡出后自毁
	if _finish_time_left >= 0.0:
		_finish_time_left -= delta
		if _finish_time_left <= 0.0:
			die()
		return

	_cooldown -= 60.0 * delta
	if _cooldown > 0.0:
		return

	_cooldown = WeaponService.apply_structure_attack_speed_effects(stats.cooldown, player_index)

	# devour structures inside the range (open phase only)
	_devour_scan_cooldown -= delta
	if _devour_scan_cooldown <= 0.0:
		_devour_scan_cooldown = DEVOUR_SCAN_INTERVAL
		_devour_structures_in_area()

	_player_pull_cooldown -= 60.0 * delta
	if _player_pull_cooldown <= 0.0:
		_player_pull_cooldown = WeaponService.apply_structure_attack_speed_effects(stats.cooldown, player_index)
		_pull_players_in_area()

	if not _damage_and_pull_enemies_in_area():
		return

	_attacks_done += 1
	if _attacks_done >= _attacks_before_close:
		_attacks_done = 0
		_finish_time_left = CORE_FADE_TIME
		_set_area_closed(true)


# 核心的淡出（任何状态下每帧推进）
func _update_core_fade(delta: float) -> void:
	var step: float = delta / max(0.01, CORE_FADE_TIME)
	if _core != null:
		_core.modulate.a = move_toward(_core.modulate.a, _core_alpha_target, step)



func _damage_and_pull_enemies_in_area() -> bool:
	var targets: = []
	for enemy in _enemies_in_area:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.get_charmed_by_player_index() >= 0:
			continue
		targets.append(enemy)
	_enemies_in_area = targets

	if targets.size() == 0:
		return false

	var pull_distance: float = _resolve_pull_distance()
	var center: Vector2 = global_position

	for enemy in targets:
		var args: = TakeDamageArgs.new(player_index, _hitbox)
		args.from = self
		var dmg_taken: Array = enemy.take_damage(_hitbox.damage, args)
		if dmg_taken.size() > 1:
			_hitbox.hit_something(enemy, dmg_taken[1])

		if pull_distance <= 0.0:
			continue

		_apply_pull(enemy, center, pull_distance)

	return true


# 抵消击退抗性的除数（下限 MIN_RESIST_FACTOR，避免 0 除）
func _get_pull_resist_factor(resist: float) -> float:
	return clamp(1.0 - resist, MIN_RESIST_FACTOR, 1.0)


# 吸引：走原版击退通道（每帧衰减 10%，总位移 ≈ 向量 × 10），并抵消击退抗性
func _apply_pull(enemy, center: Vector2, distance: float) -> void:
	if distance <= 0.0 or enemy == null or not is_instance_valid(enemy):
		return

	var to_center: Vector2 = center - enemy.global_position
	if to_center.length() <= 1.0:
		return

	var resist: float = 0.0
	if enemy.stats != null:
		resist = float(enemy.stats.knockback_resistance)
	var resist_factor: float = _get_pull_resist_factor(resist)

	enemy.knockback_vector = to_center.normalized() * (distance * KNOCKBACK_DECAY) / resist_factor


# 吸引距离 = max(构筑物面板击退, 玩家当前「黑洞发生器」武器的面板击退)；
# 两者都为 0 时用效果资源给的兜底值 —— 这样「构筑物」侧的击退加成也能生效
func _resolve_pull_distance() -> float:
	var best: float = 0.0

	# 构筑物面板击退（init_structure_stats 后的值，已含玩家击退加成）
	if stats != null:
		best = max(best, float(stats.knockback))

	if player_index >= 0:
		for weapon in RunData.get_player_weapons(player_index):
			if weapon == null or not is_instance_valid(weapon):
				continue
			if not ("weapon_id" in weapon) or not ("current_stats" in weapon):
				continue
			if str(weapon.weapon_id) != BLACK_HOLE_WEAPON_ID:
				continue
			if weapon.current_stats != null:
				best = max(best, float(weapon.current_stats.knockback))

	if best <= 0.0:
		best = _pull_distance

	return best * PULL_DISTANCE_RATIO


# closed = true：核心淡出、停止结算；instant = true 时立即设为目标透明度
func _set_area_closed(closed: bool, instant: bool = false) -> void:
	_core_alpha_target = 0.0 if closed else 1.0
	if instant:
		if _core != null:
			_core.modulate.a = _core_alpha_target


# ---------- 中继器（建筑攻速加成）接口 ----------

func fengliu_set_relay_attack_speed(source: Object, percent: int) -> void:
	WeaponService.fengliu_set_relay_attack_speed(self, source, percent)


func fengliu_clear_relay_attack_speed(source: Object) -> void:
	WeaponService.fengliu_clear_relay_attack_speed(self, source)


func fengliu_get_relay_attack_speed_percent() -> int:
	return WeaponService.fengliu_get_relay_attack_speed_percent(self)


func fengliu_apply_relay_attack_speed_to_cooldown(base_cooldown: int) -> int:
	return WeaponService.fengliu_apply_relay_attack_speed_to_cooldown(self, base_cooldown)

# 与 clean_up_room 的重复 die 调用兼容（已死时直接返回，避免 Structure.die 的 assert）
func die(args = Utils.default_die_args) -> void:
	if dead:
		return

	.die(args)


func _attach_core_to_layer() -> void:
	if _core == null:
		return

	var main = Utils.get_scene_node()
	if main == null:
		return

	var container = _fengliu_get_visual_layer(main)
	if container == null:
		return

	if _core.get_parent() == container:
		_core_attached_to_container = true
		return

	var core_parent = _core.get_parent()
	if core_parent != null:
		core_parent.remove_child(_core)
	container.add_child(_core)
	_core.z_index = 0
	_core.global_position = global_position + VISUAL_OFFSET
	_core_attached_to_container = true


func _fengliu_get_visual_layer(main) -> Node2D:
	var layer = main.get_node_or_null(VISUAL_LAYER_NAME) as Node2D
	if layer != null:
		return layer

	var entities = main.get_node_or_null('Entities')
	if entities == null:
		return null

	layer = Node2D.new()
	layer.name = VISUAL_LAYER_NAME
	main.add_child(layer)
	main.move_child(layer, entities.get_index())
	return layer


func _exit_tree() -> void:
	_core_attached_to_container = false
	if _core != null and is_instance_valid(_core) and _core.get_parent() != self:
		var core_parent = _core.get_parent()
		if core_parent != null:
			core_parent.remove_child(_core)
		add_child(_core)
		_core.position = VISUAL_OFFSET


func _update_grass_state(delta: float) -> void:
	_grass_state_time_left -= delta
	if _grass_state_time_left > 0.0:
		return
	_grass_state_time_left = GRASS_STATE_INTERVAL

	var main = Utils.get_scene_node()
	if main == null or not ('_entities_container' in main) or main._entities_container == null:
		return

	var radius: float = get_black_hole_radius()
	var center: Vector2 = global_position
	for child in main._entities_container.get_children():
		if not is_instance_valid(child) or not (child is SpriteDestructible):
			continue
		if child.global_position.distance_to(center) <= radius:
			child.fengliu_apply_range_state()


func _apply_core_texture() -> void:
	if _core == null or _core_texture_loaded:
		return

	var img: = Image.new()
	if img.load(CORE_TEXTURE_PATH) != OK:
		return

	if img.get_width() != CORE_TEXTURE_SIZE or img.get_height() != CORE_TEXTURE_SIZE:
		img.resize(CORE_TEXTURE_SIZE, CORE_TEXTURE_SIZE, Image.INTERPOLATE_BILINEAR)

	var tex: = ImageTexture.new()
	tex.create_from_image(img)
	_core.texture = tex
	_core_texture_loaded = true

	if _core_radius_current > 0.0:
		_apply_core_scale()


func _pull_players_in_area() -> void:
	var pull_distance: float = _resolve_pull_distance() * PLAYER_PULL_RATIO
	if pull_distance <= 0.0:
		return

	var center: Vector2 = global_position
	for player in _players_in_area:
		if player == null or not is_instance_valid(player) or player.dead:
			continue

		_apply_pull(player, center, pull_distance)


const DEVOUR_SKIP_SCRIPTS := ['black_hole.gd', 'black_hole_device.gd']


func _devour_structures_in_area() -> void:
	var main = Utils.get_scene_node()
	if main == null or not ('_entity_spawner' in main) or main._entity_spawner == null:
		return

	var radius: float = get_black_hole_radius()
	var center: Vector2 = global_position
	for st in main._entity_spawner.structures.duplicate():
		if st == null or not is_instance_valid(st) or st.dead:
			continue
		if st.is_queued_for_deletion() or not st.is_inside_tree():
			continue
		
		var st_script = st.get_script()
		if st_script != null and st_script.resource_path.get_file() in DEVOUR_SKIP_SCRIPTS:
			continue
		if st.global_position.distance_to(center) > radius:
			continue

		_devour_structure(st)
		
		main._entity_spawner.structures.erase(st)
		if ('structures_to_remove_in_priority' in main._entity_spawner):
			main._entity_spawner.structures_to_remove_in_priority.erase(st)


func _devour_structure(st) -> void:
	if st == null or not is_instance_valid(st):
		return
	if not ("dead" in st) or st.dead:
		return
	if "stats" in st and st.stats != null:
		_devoured_damage += int(st.stats.damage)

	_attacks_before_close += DEVOUR_ATTACK_BONUS
	_apply_hitbox_stats()

	_add_wave_kill()
	_apply_area_shape()
	if st.has_method("die"):
		st.die()


# Capybara 蓝鲸兼容：允许被蓝鲸环绕/拖动（收束中的黑洞不再被拖动）
func fengliu_capybara_can_orbit() -> bool:
	return not dead and _finish_time_left < 0.0
