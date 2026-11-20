extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/ranged/ranged_weapon.gd"


# ============================================================
# 万象天引（武器）
#   血量全满时：消耗血量至 1 点（不消耗护盾），
#   在施放瞬间的角色位置召唤大陨石（从右上高处按水平 50° 斜落），
#   落地后对「爆炸直径 = 武器射程」内所有敌人造成面板伤害，并留下与爆炸同大小的火圈。
#   本武器不发射任何子弹（由 universal_pull_no_attack 动作禁止普通攻击）。
# ============================================================

const METEOR_SCENE = preload("res://mods-unpacked/FengLiu-FengAddMods/projectiles/meteor/meteor.tscn")
const METEOR_EXPLOSION_SCENE = preload("res://projectiles/explosion.tscn")
# 火圈由 mod 的 WeaponService.explode() 扩展生成：识别到该脚本才会在爆点留火
const METEOR_FIRE_EFFECT_SCRIPT = preload("res://mods-unpacked/FengLiu-FengAddMods/effects/weapons/effect_fire_exploding.gd")
# explosion.tscn 命中圆基础半径
const METEOR_BASE_RADIUS := 147.34
# 两次施放之间的最小间隔（防抖；实际频率由回满速度决定）
const METEOR_MIN_CAST_INTERVAL := 0.5
const METEOR_SMOKE_AMOUNT := 40
const METEOR_SOUND_DB_MOD := -10
# 消耗后保留的生命值（不会自杀）
const METEOR_HP_LEFT := 1
# 火圈：半径 = 爆炸实际半径 × 该倍率（1.0 ⇒ 与爆炸同大小）
const METEOR_FIRE_SCALE := 1.0
# 火圈存活时间（秒）
const METEOR_FIRE_DURATION := 7.0
# 火圈点燃间隔（秒）
const METEOR_FIRE_TICK_INTERVAL := 0.5
# 火圈火焰粒子数量（大范围需要较多粒子才不稀疏）
const METEOR_FIRE_PARTICLE_COUNT := 32
# 每波开局前 x 秒不施放
const METEOR_WAVE_START_DELAY := 1.0
# 陨石下降时长（秒）：基准 = cooldown/60（1~4 阶 = 4.0 / 3.5 / 3.0 / 2.5），再按玩家攻速缩短
const METEOR_FALL_MIN := 0.25
const METEOR_FALL_MAX := 6.0

var _fengliu_cast_cooldown := 0.0
# 正在下落中的陨石数量（同时只允许 1 颗，避免 2 秒内回满后叠放）
var _fengliu_meteors_in_flight := 0


# 屏蔽原版射击流程由 universal_pull_no_attack 动作负责
func _physics_process(delta: float) -> void:
	._physics_process(delta)

	_fengliu_cast_cooldown = max(_fengliu_cast_cooldown - delta, 0.0)
	if _fengliu_cast_cooldown > 0.0:
		return

	_fengliu_try_cast_meteor()


# 判定：只要生命全满即可施放（不要求护盾；负护盾上限也可施放）
func fengliu_can_cast_meteor(health: float, max_health: float) -> bool:
	if max_health <= 0.0:
		return false

	return health >= max_health


# 陨石伤害范围半径 = 武器射程 / 2（爆炸直径 = 武器射程）
func fengliu_get_meteor_radius(weapon_range: float) -> float:
	return max(0.0, weapon_range) * 0.5


# 目标半径换算成爆炸场景缩放
func fengliu_get_meteor_scale(radius: float) -> float:
	return max(0.1, radius / METEOR_BASE_RADIUS)


# 陨石下降时长（秒）：基准 = cooldown/60（1~4 阶 = 4 / 3.5 / 3 / 2.5），再按玩家攻速缩短
func fengliu_get_meteor_fall_duration() -> float:
	var base_seconds: float = float(current_stats.cooldown) / 60.0
	var attack_speed: float = 0.0
	if player_index >= 0:
		var attack_speed_value = Utils.get_stat(Keys.stat_attack_speed_hash, player_index)
		if attack_speed_value is float or attack_speed_value is int:
			attack_speed = float(attack_speed_value)

	return fengliu_get_meteor_fall_duration_from(base_seconds, attack_speed)


# 纯函数：按基准秒数与攻速百分比算下降时长（夹在 METEOR_FALL_MIN ~ METEOR_FALL_MAX）
func fengliu_get_meteor_fall_duration_from(base_seconds: float, attack_speed: float) -> float:
	return clamp(
		base_seconds / (1.0 + max(0.0, attack_speed) / 100.0),
		METEOR_FALL_MIN,
		METEOR_FALL_MAX
	)


# 纯函数：本波已过的秒数是否已过开局延迟（便于探针断言）
func fengliu_is_start_delay_passed(wave_elapsed: float) -> bool:
	return wave_elapsed >= METEOR_WAVE_START_DELAY


# 当前是否处于开局延迟：非战斗中（商店/结算）一律视为延迟中
func _fengliu_is_in_start_delay() -> bool:
	if not RunData.wave_in_progress:
		return true

	var wave_timer = RunData.wave_timer
	if wave_timer == null:
		return false

	# 本波已过时间 = 总时长 - 剩余时间
	return not fengliu_is_start_delay_passed(wave_timer.wait_time - wave_timer.time_left)


func _fengliu_try_cast_meteor() -> void:
	# 每波开局前 5 秒不施放（放在最前面，省掉后续判定开销）
	if _fengliu_is_in_start_delay():
		return

	# 上一颗还在下落时不施放
	if _fengliu_meteors_in_flight > 0:
		return

	var player = _parent
	if player == null or not is_instance_valid(player) or player.dead:
		return

	if player_index < 0:
		return

	if not fengliu_can_cast_meteor(player.current_stats.health, player.max_stats.health):
		return

	var radius: float = fengliu_get_meteor_radius(current_stats.max_range)
	if not _fengliu_has_enemy_in_radius(player.global_position, radius):
		return

	_fengliu_consume_resources(player)
	_fengliu_spawn_meteor(player, radius)
	_fengliu_cast_cooldown = METEOR_MIN_CAST_INTERVAL


# 消耗：只把血量压至 1 点（不扣护盾；不走受击流程，避免触发受击类效果与无敌帧）
func _fengliu_consume_resources(player) -> void:
	player.current_stats.health = METEOR_HP_LEFT
	player.emit_signal("health_updated", player, player.current_stats.health, player.max_stats.health)


# 半径内是否有活着的敌人（避免清场后白白消耗资源）
func _fengliu_has_enemy_in_radius(center: Vector2, radius: float) -> bool:
	if not ("_entity_spawner_ref" in _parent) or _parent._entity_spawner_ref == null:
		return false

	var radius_squared: float = radius * radius
	for enemy in _parent._entity_spawner_ref.get_all_enemies(false):
		if enemy == null or not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.global_position.distance_squared_to(center) > radius_squared:
			continue
		return true

	return false


# 生成陨石：伤害/暴击/缩放取当前武器面板，落点＝玩家当前坐标；落地爆炸后留火圈
func _fengliu_spawn_meteor(player, radius: float) -> void:
	# 用 mod 的「爆炸 + 火圈」效果：WeaponService.explode() 会识别该脚本并在爆点生成火圈
	var effect = METEOR_FIRE_EFFECT_SCRIPT.new()
	effect.explosion_scene = METEOR_EXPLOSION_SCENE
	effect.scale = fengliu_get_meteor_scale(radius)
	effect.base_smoke_amount = METEOR_SMOKE_AMOUNT
	effect.sound_db_mod = METEOR_SOUND_DB_MOD
	effect.fire_scale = METEOR_FIRE_SCALE
	effect.fire_duration = METEOR_FIRE_DURATION
	effect.fire_tick_interval = METEOR_FIRE_TICK_INTERVAL
	effect.fire_particle_count = METEOR_FIRE_PARTICLE_COUNT

	var args = WeaponServiceExplodeArgs.new()
	args.pos = player.global_position
	args.damage = current_stats.damage
	args.scaling_stats = current_stats.scaling_stats
	args.accuracy = current_stats.accuracy
	args.crit_chance = current_stats.crit_chance + Utils.get_capped_stat(Keys.stat_crit_chance_hash, player_index) / 100.0
	args.crit_damage = current_stats.crit_damage
	args.from_player_index = player_index
	args.from = self
	# 燃烧数据来自武器词条（BurningEffect + burning_data 资源），已按元素/伤害加成缩放
	args.burning_data = current_stats.burning_data

	var meteor = METEOR_SCENE.instance()
	meteor.init(args.pos, effect, args, fengliu_get_meteor_fall_duration())
	meteor.connect("explosion_created", self, "_fengliu_on_meteor_explosion")

	var main = Utils.get_scene_node()
	if main == null:
		meteor.queue_free()
		return

	# 记录在飞数量：陨石离开场景树（落地自毁）时递减
	_fengliu_meteors_in_flight += 1
	meteor.connect("tree_exited", self, "_fengliu_on_meteor_gone")

	main.add_effect(meteor)


# 陨石已离开场景树（落地自毁）时解除在飞标记
func _fengliu_on_meteor_gone() -> void:
	_fengliu_meteors_in_flight = max(0, _fengliu_meteors_in_flight - 1)


# 陨石落地后：把爆炸的命中/击杀接回武器（照 unit.gd 的接法）
func _fengliu_on_meteor_explosion(explosion) -> void:
	if explosion == null or not is_instance_valid(explosion):
		return

	explosion.connect("hit_something", self, "on_weapon_hit_something", [explosion._hitbox])
	if not explosion.is_connected("killed_something", self, "on_killed_something"):
		explosion.connect("killed_something", self, "on_killed_something", [explosion._hitbox])
