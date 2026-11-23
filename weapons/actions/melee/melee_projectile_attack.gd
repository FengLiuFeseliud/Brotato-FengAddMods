extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/melee/melee_action.gd"


# ============================================================
# 近战被动动作：挥击射击
#   不强制攻击、不锁朝向；挂到武器后每次普通近战攻击都会发射子弹。
#   动作无需常驻激活，由近战武器的被动钩子调用。
#   面板射程与挥击动画/命中保持原值；索敌、开火判定与子弹射程按 面板 max_range × range_multiplier。
#   本动作不依赖额外 .tres，子弹参数直接导出到动作资源上。
# ------------------------------------------------------------
# 可配置参数：
#   projectile_scene       子弹场景（材质/动画随场景；为空时不发射）
#   nb_projectiles         每次攻击发射的子弹数
#   range_multiplier       索敌/开火与子弹射程 = 近战面板 max_range × 该倍率
#   projectile_speed       子弹速度
#   piercing               穿透次数
#   bounce                 反弹次数
#   spread                 多颗子弹的总扇形角度（弧度；0 = 同向）
# ============================================================

export(PackedScene) var projectile_scene
export(int) var nb_projectiles = 3
export(float) var range_multiplier = 1.0
export(int) var projectile_speed = 1500
export(int) var piercing = 0
export(int) var bounce = 0
export(float) var spread = 0.0

var _fengliu_base_max_range := 0
var _fengliu_attack_range := 0
var _fengliu_warned_missing_scene := false
var _fengliu_cached_source_stats = null
var _fengliu_cached_projectile_stats = null


# 武器描述占位：{0} = 射程倍率
func get_args(_player_index: int = -1) -> Array:
	var value: float = range_multiplier
	var value_text: String = str(int(round(value))) if is_equal_approx(value, round(value)) else str(value)
	return [value_text]


# 初始化时立即应用索敌/开火射程覆盖，不要求动作处于激活状态
func fengliu_setup(weapon) -> void:
	.fengliu_setup(weapon)
	_fengliu_clear_projectile_stats_cache()
	_fengliu_refresh_range()


# 被动物理帧：维持索敌/开火射程覆盖（波次重算后也会重新应用）
func fengliu_on_passive_physics_process(_delta: float) -> void:
	_fengliu_refresh_range()


# 武器属性重建后清空缓存；下次攻击按新属性重建
func fengliu_on_weapon_stats_initialized() -> void:
	_fengliu_clear_projectile_stats_cache()
	_fengliu_refresh_range()


# 每次普通近战攻击后发射子弹（被动钩子）
func fengliu_on_passive_after_shoot() -> void:
	var weapon = _fengliu_weapon
	if weapon == null or not is_instance_valid(weapon):
		return

	_fengliu_refresh_range()

	# 缺少子弹场景时不生成，避免运行期空引用
	if projectile_scene == null:
		if not _fengliu_warned_missing_scene:
			_fengliu_warned_missing_scene = true
			push_warning("melee_projectile_attack: projectile_scene is null")
		return

	var projectile_params = _fengliu_build_projectile_stats(weapon)
	if projectile_params == null:
		return

	var count: int = max(1, int(projectile_params.nb_projectiles))
	var attack_id: int = 1
	if weapon._shooting_behavior != null and weapon._shooting_behavior.has_method("_get_next_attack_id"):
		attack_id = weapon._shooting_behavior._get_next_attack_id()

	var spawn_args = WeaponServiceSpawnProjectileArgs.new()
	spawn_args.effects = weapon.effects.duplicate() if weapon.effects != null else []
	spawn_args.from_player_index = weapon.player_index

	var muzzle = weapon.get("muzzle")
	var spawn_position: Vector2 = muzzle.global_position if muzzle != null else weapon.global_position

	for i in count:
		var direction: float = _fengliu_get_projectile_direction(weapon.rotation, count, i)
		if projectile_params.projectile_spread > 0.0:
			direction += rand_range(-projectile_params.projectile_spread, projectile_params.projectile_spread)
		spawn_args.knockback_direction = Vector2(cos(direction), sin(direction))

		var projectile = WeaponService.spawn_projectile(spawn_position, projectile_params, direction, weapon, spawn_args)
		if not is_instance_valid(projectile):
			continue

		_fengliu_connect_projectile(weapon, projectile, attack_id)


# 记录索敌/开火与子弹射程覆盖值，并同步 Range 检测形状
func _fengliu_refresh_range() -> void:
	var weapon = _fengliu_weapon
	if weapon == null or not is_instance_valid(weapon) or weapon.current_stats == null:
		return

	var current_range: int = int(weapon.current_stats.max_range)
	if current_range != _fengliu_attack_range:
		_fengliu_base_max_range = current_range
		_fengliu_attack_range = max(1, int(round(float(_fengliu_base_max_range) * max(0.01, range_multiplier))))

	if weapon.has_method("fengliu_set_attack_range_override"):
		weapon.fengliu_set_attack_range_override(_fengliu_attack_range)


# 复制近战面板属性与配置，并通过原版远程初始化兼容玩家效果
func _fengliu_build_projectile_stats(weapon):
	var source = weapon.current_stats
	if source == null:
		return null

	var player_index: int = weapon.player_index

	if _fengliu_cached_projectile_stats == null or _fengliu_cached_source_stats != source:
		_fengliu_rebuild_projectile_stats(weapon, source, player_index)

	var projectile_params = _fengliu_cached_projectile_stats
	if projectile_params == null:
		return null

	_fengliu_apply_panel_stats(projectile_params, source)
	return projectile_params


# 重建缓存：原版初始化只在这里执行
func _fengliu_rebuild_projectile_stats(weapon, source, player_index: int) -> void:
	_fengliu_cached_source_stats = source
	_fengliu_cached_projectile_stats = null

	var base_stats = RangedWeaponStats.new()
	base_stats.projectile_scene = projectile_scene
	base_stats.projectile_speed = max(1, projectile_speed)
	base_stats.piercing = max(0, piercing)
	base_stats.bounce = max(0, bounce)
	base_stats.can_bounce = true
	base_stats.max_range = max(1, _fengliu_attack_range)
	base_stats.damage = max(1, source.damage)
	base_stats.nb_projectiles = max(1, nb_projectiles)
	base_stats.accuracy = source.accuracy
	base_stats.crit_chance = source.crit_chance
	base_stats.crit_damage = source.crit_damage
	base_stats.knockback = source.knockback
	base_stats.knockback_piercing = source.knockback_piercing
	base_stats.effect_scale = source.effect_scale
	base_stats.lifesteal = source.lifesteal
	base_stats.speed_percent_modifier = source.speed_percent_modifier
	base_stats.is_healing = source.is_healing
	base_stats.min_range = 0
	base_stats.piercing_dmg_reduction = 1.0
	base_stats.bounce_dmg_reduction = 1.0
	base_stats.can_shoot_without_target = true
	base_stats.scaling_stats = []

	if source.burning_data != null:
		base_stats.burning_data = source.burning_data.duplicate()
		base_stats.burning_data.from = weapon

	var projectile_params = base_stats
	if player_index >= 0:
		projectile_params = WeaponService.init_ranged_stats(base_stats, player_index, true)

	if source.scaling_stats != null:
		projectile_params.scaling_stats = source.scaling_stats.duplicate()

	if source.burning_data != null:
		projectile_params.burning_data = source.burning_data.duplicate()
		projectile_params.burning_data.from = weapon

	_fengliu_cached_projectile_stats = projectile_params


# 每次攻击只更新面板动态值，保留缓存的玩家效果结果
func _fengliu_apply_panel_stats(projectile_params, source) -> void:
	projectile_params.damage = max(1, source.damage)
	projectile_params.accuracy = source.accuracy
	projectile_params.crit_chance = source.crit_chance
	projectile_params.crit_damage = source.crit_damage
	projectile_params.knockback = source.knockback
	projectile_params.knockback_piercing = source.knockback_piercing
	projectile_params.effect_scale = source.effect_scale
	projectile_params.lifesteal = source.lifesteal
	projectile_params.speed_percent_modifier = source.speed_percent_modifier
	projectile_params.is_healing = source.is_healing
	projectile_params.max_range = max(1, _fengliu_attack_range)


func _fengliu_clear_projectile_stats_cache() -> void:
	_fengliu_cached_source_stats = null
	_fengliu_cached_projectile_stats = null


# 多颗子弹按 spread 均匀铺开；spread 为 0 时全部同向
func _fengliu_get_projectile_direction(base_rotation: float, count: int, index: int) -> float:
	if count <= 1 or spread <= 0.0:
		return base_rotation

	var step: float = spread / float(count - 1)
	return base_rotation - spread * 0.5 + step * float(index)


# 子弹命中/击杀/暴击接回近战武器，保证伤害统计正常
func _fengliu_connect_projectile(weapon, projectile, attack_id: int) -> void:
	var hitbox = projectile.get("_hitbox")
	if hitbox == null:
		return

	hitbox.player_attack_id = attack_id

	if not projectile.hit_something_connected:
		var _error = projectile.connect("hit_something", weapon, "on_weapon_hit_something", [hitbox])
		projectile.hit_something_connected = true

	if not projectile.killed_something_connected:
		var _error2 = hitbox.connect("killed_something", weapon, "on_killed_something", [hitbox])
		projectile.killed_something_connected = true

	if not projectile.critically_hit_something_connected:
		var _error3 = projectile.connect("critically_hit_something", weapon, "_on_weapon_critically_hit_something")
		projectile.critically_hit_something_connected = true