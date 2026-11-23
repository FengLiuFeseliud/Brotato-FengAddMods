extends Reference


# ============================================================
# 通用形态泥潭行为：形态选择、子弹染色、泥潭生成
#   配置由 action .tres 提供；本脚本无 class_name，使用 preload 调用静态方法。
# ============================================================


# 按进化与路线限制返回可用形态
static func get_available_forms(evolution: float, dual: bool, meca_only: bool, mutant_only: bool, config) -> Array:
	if dual and evolution != 0.0:
		return [int(config.form_mutant), int(config.form_meca)]
	if meca_only and not mutant_only:
		return [int(config.form_meca)]
	if mutant_only and not meca_only:
		return [int(config.form_mutant)]
	if evolution < 0.0:
		return [int(config.form_mutant)]
	if evolution > 0.0:
		return [int(config.form_meca)]
	return [int(config.form_neutral)]


# 按当前玩家的进化状态随机取一个可用形态
static func pick_form(player_index: int, config) -> int:
	var forms: Array = get_available_forms(
		Utils.get_stat(Keys.stat_evolution_hash, player_index),
		RunData.is_dual_evolution(player_index),
		RunData.is_meca_only(player_index),
		RunData.is_mutant_only(player_index),
		config
	)
	return forms[randi() % forms.size()]


# 按形态给子弹染色
static func apply_projectile_form(projectile: Node2D, form: int, config) -> void:
	if projectile == null or not "_sprite" in projectile or projectile._sprite == null:
		return

	var tint: Color = config.form_tints.get(form, Color.white)
	var alpha: float = projectile._sprite.modulate.a
	projectile._sprite.modulate = Color(tint.r, tint.g, tint.b, alpha)


# 取某形态对应的武器效果（提供泥潭伤害/减速参数）
static func get_form_effect(effects: Array, form: int, config):
	var effect_key: String = config.form_effect_keys.get(form, "")
	if effect_key == "":
		return null

	for effect in effects:
		if effect is CarbonBowStatEffect and effect.key == effect_key:
			return effect

	return null


# 泥潭半径：基础半径 × 武器阶数倍率 × 泥潭尺寸属性
static func get_puddle_radius(tier: int, config) -> float:
	var multipliers: Array = config.puddle_radius_tier_multipliers
	var tier_index: int = clamp(tier, 0, multipliers.size() - 1)
	return float(config.puddle_radius) * float(multipliers[tier_index]) * Utils.get_fengliu_puddle_size_multiplier()


# 组装一次泥潭生成数据；普通形态返回空字典
static func build_puddle_data(form: int, thing_hit: Node, damage_dealt: int, projectile: Node2D, effects: Array, tier: int, config) -> Dictionary:
	if form == int(config.form_neutral):
		return {}

	var pos: Vector2 = projectile.global_position if is_instance_valid(projectile) else Vector2.ZERO
	if is_instance_valid(thing_hit) and "global_position" in thing_hit:
		pos = thing_hit.global_position

	var effect = get_form_effect(effects, form, config)
	var data := {
		"form": form,
		"pos": pos,
		"damage": 0,
		"tick": float(config.puddle_tick_interval),
		"slow_percent": float(config.puddle_slow_percent),
		"slow_hold": float(config.puddle_slow_hold),
		"radius": get_puddle_radius(tier, config),
	}

	if form == int(config.form_mutant):
		var percent: float = float(effect.value) if effect != null else float(config.puddle_damage_percent)
		var tick: float = float(effect.duration) if effect != null else float(config.puddle_tick_interval)
		data.damage = max(1, int(round(max(1, damage_dealt) * percent / 100.0)))
		data.tick = tick
	else:
		data.slow_percent = float(effect.value) if effect != null else float(config.puddle_slow_percent)
		data.slow_hold = float(effect.duration) if effect != null else float(config.puddle_slow_hold)

	return data


# 在主场景生成泥潭；返回生成的泥潭节点
static func spawn_puddle(data: Dictionary, player_index: int, config, weapon = null):
	if data.empty():
		return null

	var main = Utils.get_scene_node()
	if main == null:
		return null

	var puddle = config.puddle_scene.instance()
	main.add_child(puddle)
	var ground = main.get_node_or_null("TileMap")
	if ground != null:
		main.move_child(puddle, ground.get_index() + 1)
	puddle.global_position = data.pos

	if int(data.form) == int(config.form_mutant):
		puddle.init_puddle(
			int(config.puddle_mode_acid),
			int(data.damage),
			player_index,
			float(data.radius),
			float(config.puddle_lifetime),
			float(data.tick),
			0.0,
			0.0,
			weapon
		)
	else:
		puddle.init_puddle(
			int(config.puddle_mode_slow),
			0,
			player_index,
			float(data.radius),
			float(config.puddle_lifetime),
			float(config.puddle_tick_interval),
			float(data.slow_percent),
			float(data.slow_hold),
			weapon
		)

	return puddle
