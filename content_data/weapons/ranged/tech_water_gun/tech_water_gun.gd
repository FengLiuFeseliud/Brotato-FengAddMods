extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/ranged/ranged_weapon.gd"


# ============================================================
# 科技水枪：8 发水弹，异变/机械形态与进化泥潭
#   - 异变：负进化每点 +0.3 伤害，命中生成酸液泥潭（伤害敌人）
#   - 机械：正进化每点 +0.3 伤害，命中生成机械泥潭（减速敌人）
#   - 未进路线：普通水弹，命中无额外效果
# ============================================================

export(Resource) var behavior_action

const PUDDLE_BEHAVIOR = preload("res://mods-unpacked/FengLiu-FengAddMods/weapons/behaviors/tech_puddle_behavior.gd")

var _forms: = {}
var _built_evolution: = 0.0
var _built_dual: = false


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

	var args: = WeaponServiceInitStatsArgs.new()
	args.sets = weapon_sets
	args.effects = effects

	var forms := [
		int(behavior_action.get("form_mutant")),
		int(behavior_action.get("form_meca")),
		int(behavior_action.get("form_neutral")),
	]
	for form in forms:
		var base_stats = stats.duplicate()
		base_stats.scaling_stats = _build_scaling_stats_for(form)

		var variant = WeaponService.init_ranged_stats(base_stats, player_index, false, args)
		variant.burning_data.from = self
		_forms[form] = variant


func _build_scaling_stats_for(form: int) -> Array:
	var new_scaling_stats: = []
	var source_scaling_stats = stats.scaling_stats if stats.scaling_stats != null else []
	var form_mutant: int = int(behavior_action.get("form_mutant"))
	var form_meca: int = int(behavior_action.get("form_meca"))

	for entry in source_scaling_stats:
		if not (entry is Array) or entry.size() < 2:
			new_scaling_stats.append(entry)
			continue

		var entry_key = entry[0]
		if entry_key is String:
			entry_key = Keys.generate_hash(entry_key)

		if Utils.is_fengliu_evolution_scaling_key(entry_key):
			var magnitude: float = abs(float(entry[1]))

			if form == form_mutant:
				new_scaling_stats.append([entry[0], - magnitude])
			elif form == form_meca:
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
	return PUDDLE_BEHAVIOR.get_available_forms(evolution, dual, meca_only, mutant_only, behavior_action)


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


func get_projectile_form_meta() -> String:
	return String(behavior_action.get("projectile_form_meta"))


func apply_projectile_form(projectile: Node2D, form: int) -> void :
	PUDDLE_BEHAVIOR.apply_projectile_form(projectile, form, behavior_action)


# custom shooting behavior 已在发射时决定形态；动作侧不再覆盖
func fengliu_uses_custom_projectile_forms() -> bool:
	return true


