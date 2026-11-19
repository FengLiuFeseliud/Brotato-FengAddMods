extends "res://weapons/ranged/ranged_weapon.gd"


# ============================================================
# 科技水枪：8 发水弹，异变/机械形态与进化泥潭
#   - 异变：负进化每点 +0.3 伤害，命中生成酸液泥潭（伤害敌人）
#   - 机械：正进化每点 +0.3 伤害，命中生成机械泥潭（减速敌人）
#   - 未进路线：普通水弹，命中无额外效果
# ============================================================


enum Form { MUTANT, MECA, NEUTRAL }

const PROJECTILE_FORM_META: = "tech_water_gun_form"


const PUDDLE_SCENE = preload("res://mods-unpacked/FengLiu-FengAddMods/projectiles/tech_puddles/tech_puddle.tscn")
const PUDDLE_RADIUS: = 60.0
const PUDDLE_RADIUS_TIER_MULTIPLIERS: = [1.25, 1.5, 1.75, 2.0]
const PUDDLE_LIFETIME: = 3.0
const PUDDLE_TICK_INTERVAL: = 0.5
const PUDDLE_MODE_ACID: = 0
const PUDDLE_MODE_SLOW: = 1
const PUDDLE_SLOW_PERCENT: = 30.0
const PUDDLE_SLOW_HOLD: = 3.0
const PUDDLE_DAMAGE_PERCENT: = 50.0

const FORM_EFFECT_KEYS: = {
	Form.MUTANT: "fengliu_tech_water_gun_mutant",
	Form.MECA: "fengliu_tech_water_gun_meca",
}

const FORM_TINTS: = {
	Form.MUTANT: Color(0.416, 0.745, 0.188, 1.0),
	Form.MECA: Color(0.7, 0.7, 0.7, 1.0),
	Form.NEUTRAL: Color.white,
}

var _forms: = {}
var _form_effects: = {}
var _built_evolution: = 0.0
var _built_dual: = false
var _puddles: = []


func init_stats(at_wave_begin: bool = true) -> void :
	.init_stats(at_wave_begin)
	_build_forms(
		Utils.get_stat(Keys.stat_evolution_hash, player_index),
		RunData.is_dual_evolution(player_index)
	)


func _build_forms(evolution: float, dual: bool) -> void :
	_built_evolution = evolution
	_built_dual = dual
	_forms.clear()
	_form_effects.clear()

	for effect in effects:
		if effect is CarbonBowStatEffect and FORM_EFFECT_KEYS.values().has(effect.key):
			_form_effects[effect.key] = effect

	var args: = WeaponServiceInitStatsArgs.new()
	args.sets = weapon_sets
	args.effects = effects

	for form in [Form.MUTANT, Form.MECA, Form.NEUTRAL]:
		var base_stats = stats.duplicate()
		base_stats.scaling_stats = _build_scaling_stats_for(form)

		var variant = WeaponService.init_ranged_stats(base_stats, player_index, false, args)
		variant.burning_data.from = self
		_forms[form] = variant


func _build_scaling_stats_for(form: int) -> Array:
	var new_scaling_stats: = []
	var source_scaling_stats = stats.scaling_stats if stats.scaling_stats != null else []

	for entry in source_scaling_stats:
		if not (entry is Array) or entry.size() < 2:
			new_scaling_stats.append(entry)
			continue

		var entry_key = entry[0]
		if entry_key is String:
			entry_key = Keys.generate_hash(entry_key)

		if Utils.is_fengliu_evolution_scaling_key(entry_key):
			var magnitude: float = abs(float(entry[1]))

			if form == Form.MUTANT:
				new_scaling_stats.append([entry[0], - magnitude])
			elif form == Form.MECA:
				new_scaling_stats.append([entry[0], magnitude])
			else:
				# 进化 0 / 普通形态：同时保留正负两条路径，实际结算为 0
				new_scaling_stats.append([entry[0], magnitude])
				new_scaling_stats.append([entry[0], - magnitude])
		else:
			new_scaling_stats.append([entry[0], entry[1]])

	return new_scaling_stats


func take_next_form() -> int:
	_ensure_forms_current()
	return pick_form()


func _ensure_forms_current() -> void :
	var evolution: float = Utils.get_stat(Keys.stat_evolution_hash, player_index)
	var dual: bool = RunData.is_dual_evolution(player_index)
	if _forms.empty() or not is_equal_approx(evolution, _built_evolution) or dual != _built_dual:
		_build_forms(evolution, dual)


func get_available_forms_for(evolution: float, dual: bool, meca_only: bool, mutant_only: bool) -> Array:
	if dual and evolution != 0.0:
		return [Form.MUTANT, Form.MECA]
	if meca_only and not mutant_only:
		return [Form.MECA]
	if mutant_only and not meca_only:
		return [Form.MUTANT]
	if evolution < 0.0:
		return [Form.MUTANT]
	if evolution > 0.0:
		return [Form.MECA]
	return [Form.NEUTRAL]


func _get_available_forms() -> Array:
	return get_available_forms_for(
		Utils.get_stat(Keys.stat_evolution_hash, player_index),
		RunData.is_dual_evolution(player_index),
		RunData.is_meca_only(player_index),
		RunData.is_mutant_only(player_index)
	)


func pick_form() -> int:
	var forms: = _get_available_forms()
	return forms[randi() % forms.size()]


func get_projectile_stats(form: int) -> RangedWeaponStats:
	return _forms.get(form, current_stats)


func apply_projectile_form(projectile: Node2D, form: int) -> void :
	if projectile == null or not "_sprite" in projectile or projectile._sprite == null:
		return

	var tint: Color = FORM_TINTS.get(form, Color.white)
	var alpha: float = projectile._sprite.modulate.a
	projectile._sprite.modulate = Color(tint.r, tint.g, tint.b, alpha)


func on_projectile_shot(projectile: Node2D) -> void :
	if is_instance_valid(projectile) and not projectile.is_connected("hit_something", self, "_on_projectile_hit"):
		var _error = projectile.connect("hit_something", self, "_on_projectile_hit", [projectile])

	.on_projectile_shot(projectile)


func _on_projectile_hit(thing_hit: Node, damage_dealt: int, projectile: Node2D) -> void :
	if not is_instance_valid(projectile) or not projectile.has_meta(PROJECTILE_FORM_META):
		return

	var form: int = projectile.get_meta(PROJECTILE_FORM_META)
	if form == Form.NEUTRAL:
		return

	_try_spawn_puddle(form, thing_hit, damage_dealt, projectile)


func _try_spawn_puddle(form: int, thing_hit: Node, damage_dealt: int, projectile: Node2D) -> void :
	var pos: Vector2 = projectile.global_position
	if is_instance_valid(thing_hit) and "global_position" in thing_hit:
		pos = thing_hit.global_position

	var effect = _form_effects.get(FORM_EFFECT_KEYS.get(form, ""))
	var spawn_data: = {
		"form": form,
		"pos": pos,
		"damage": 0,
		"tick": PUDDLE_TICK_INTERVAL,
		"slow_percent": PUDDLE_SLOW_PERCENT,
		"slow_hold": PUDDLE_SLOW_HOLD,
	}

	if form == Form.MUTANT:
		var percent: float = float(effect.value) if effect != null else PUDDLE_DAMAGE_PERCENT
		var tick: float = float(effect.duration) if effect != null else PUDDLE_TICK_INTERVAL
		spawn_data.damage = max(1, int(round(max(1, damage_dealt) * percent / 100.0)))
		spawn_data.tick = tick
	else:
		spawn_data.slow_percent = float(effect.value) if effect != null else PUDDLE_SLOW_PERCENT
		spawn_data.slow_hold = float(effect.duration) if effect != null else PUDDLE_SLOW_HOLD

	# 延迟到下一帧再添加 Area2D，避免在 hit_something 物理回调里改物理状态
	call_deferred("_spawn_puddle_deferred", spawn_data)


func _spawn_puddle_deferred(spawn_data: Dictionary) -> void :
	_prune_puddles()
	var main = Utils.get_scene_node()
	if main == null:
		return

	var puddle_radius: float = _get_puddle_radius()
	var puddle = PUDDLE_SCENE.instance()
	main.add_child(puddle)
	var ground = main.get_node_or_null("TileMap")
	if ground != null:
		main.move_child(puddle, ground.get_index() + 1)
	puddle.global_position = spawn_data.pos

	if spawn_data.form == Form.MUTANT:
		puddle.init_puddle(
			PUDDLE_MODE_ACID,
			int(spawn_data.damage),
			player_index,
			puddle_radius,
			PUDDLE_LIFETIME,
			float(spawn_data.tick),
			0.0,
			0.0
		)
	else:
		puddle.init_puddle(
			PUDDLE_MODE_SLOW,
			0,
			player_index,
			puddle_radius,
			PUDDLE_LIFETIME,
			PUDDLE_TICK_INTERVAL,
			float(spawn_data.slow_percent),
			float(spawn_data.slow_hold)
		)

	_puddles.push_back(puddle)


func _get_puddle_radius() -> float:
	var tier_index: int = clamp(tier, 0, PUDDLE_RADIUS_TIER_MULTIPLIERS.size() - 1)
	return PUDDLE_RADIUS * float(PUDDLE_RADIUS_TIER_MULTIPLIERS[tier_index]) * Utils.get_fengliu_puddle_size_multiplier()


func _prune_puddles() -> void :
	var alive: = []
	for puddle in _puddles:
		if is_instance_valid(puddle) and not puddle.is_queued_for_deletion():
			alive.push_back(puddle)
	_puddles = alive

