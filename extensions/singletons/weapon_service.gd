extends "res://singletons/weapon_service.gd"


# 火圈场景：爆炸落点留下的燃烧地带
const FENGLIU_FIRE_ZONE_SCENE_PATH = "res://mods-unpacked/FengLiu-FengAddMods/projectiles/fire_zones/fire_zone.tscn"

# 水洼场景：水球爆炸落点留下的水洼（雨事件也复用同一场景）
const FENGLIU_WATER_ZONE_SCENE_PATH = "res://mods-unpacked/FengLiu-FengAddMods/projectiles/water_zones/water_zone.tscn"

# 按路径 preload 效果脚本：玩家版游戏不注册本 mod 自定义 class_name，只能用脚本对象比较
const FENGLIU_FIRE_EFFECT_SCRIPT = preload("res://mods-unpacked/FengLiu-FengAddMods/effects/weapons/effect_fire_exploding.gd")
const FENGLIU_WATER_EFFECT_SCRIPT = preload("res://mods-unpacked/FengLiu-FengAddMods/effects/weapons/effect_water_exploding.gd")

var effect_fengliu_structure_add_range = Keys.generate_hash("fengliu_structure_add_range")

# 通用进化缩放：负系数只吃负进化，正系数只吃正进化
func sum_scaling_stat_values(p_scaling_stats: Array, player_index: int) -> float:
	var normal_stats: = []
	var evolution_coefficient: float = 0.0

	for scaling_stat in p_scaling_stats:
		assert (scaling_stat[0] is int)

		if Utils.is_fengliu_evolution_scaling_key(scaling_stat[0]):
			evolution_coefficient += float(scaling_stat[1])
		else:
			normal_stats.append(scaling_stat)

	var value: float = .sum_scaling_stat_values(normal_stats, player_index)

	if evolution_coefficient == 0.0 or player_index < 0:
		return value

	var evolution: float = Utils.get_stat(Keys.stat_evolution_hash, player_index)
	var magnitude: float = abs(evolution_coefficient)

	if evolution_coefficient < 0.0:
		value += max(0.0, - evolution) * magnitude
	else:
		value += max(0.0, evolution) * magnitude

	return value


# 通用进化缩放显示：+x/-x 在进化 0 时合并为一条 ±x%
func get_scaling_stats_icon_text(p_scaling_stats: Array, compared_scaling_stats: Array = []) -> String:
	var normal_stats: = []
	var normal_compared_stats: = []
	var special_entries: = []
	var special_compared_entries: = []

	for scaling_stat in p_scaling_stats:
		assert (scaling_stat[0] is int)

		if Utils.is_fengliu_evolution_scaling_key(scaling_stat[0]):
			special_entries.append(scaling_stat)
		else:
			normal_stats.append(scaling_stat)

	for scaling_stat in compared_scaling_stats:
		if not (scaling_stat is Array) or scaling_stat.size() < 2:
			continue

		assert (scaling_stat[0] is int)
		if Utils.is_fengliu_evolution_scaling_key(scaling_stat[0]):
			special_compared_entries.append(scaling_stat)
		else:
			normal_compared_stats.append(scaling_stat)

	var text: String = .get_scaling_stats_icon_text(normal_stats, normal_compared_stats)

	if special_entries.empty():
		return text

	var positive: float = 0.0
	var negative: float = 0.0

	for entry in special_entries:
		var value: float = float(entry[1])
		if value > 0.0:
			positive += value
		elif value < 0.0:
			negative += value

	if positive > 0.0 and negative < 0.0 and is_equal_approx(positive, abs(negative)):
		text += Utils.get_fengliu_evolution_pm_icon_text(positive)
	else:
		for entry in special_entries:
			var color_override: String = _get_fengliu_compare_color(entry, special_compared_entries)
			text += Utils.get_scaling_stat_icon_text(entry[0], float(entry[1]), true, color_override)

	return text


func _get_fengliu_compare_color(entry: Array, compared_entries: Array) -> String:
	var entry_key = entry[0]
	var entry_value: float = float(entry[1])

	for compared_entry in compared_entries:
		if compared_entry[0] == entry_key and entry_value > float(compared_entry[1]):
			return "#" + ProgressData.settings.color_positive

	return ""


# 扩展构造物属性初始化（叠加全体玩家的射程加成）
func init_structure_stats(from_stats: RangedWeaponStats, player_index: int, args: WeaponServiceInitStatsArgs = _init_stats_args_service) -> RangedWeaponStats:
	var new_stats = .init_structure_stats(from_stats, player_index, args)

	# 累加全体玩家持有的“构造物射程”加成
	var bonus = 0
	for _p in RunData.get_player_count():
		var effects = RunData.get_player_effect(effect_fengliu_structure_add_range, _p)
		if effects.size() > 0:
			bonus += Utils.get_stat(effects[0][0], _p)

	# 有射程加成则叠加到最大射程
	if bonus > 0:
		new_stats.max_range = max(MIN_RANGE, new_stats.max_range + bonus)

	return new_stats


# 扩展爆炸：带火圈的爆炸效果会在爆点留下一片只点燃敌人的火
func explode(effect: ExplodingEffect, args: WeaponServiceExplodeArgs) -> Node:
	var instance = .explode(effect, args)

	# 只有「爆炸 + 火圈」效果才留火
	if effect.get_script() == FENGLIU_FIRE_EFFECT_SCRIPT:
		fengliu_spawn_fire_zone(effect, args, instance)
	# 只有「爆炸 + 水洼」效果才留水洼
	if effect.get_script() == FENGLIU_WATER_EFFECT_SCRIPT:
		fengliu_spawn_water_zone(effect, args, instance)

	return instance


# 在爆点生成火圈：半径按爆炸实际半径换算，点燃数据沿用本次爆炸的燃烧数据
func fengliu_spawn_fire_zone(effect, args: WeaponServiceExplodeArgs, explosion: Node) -> void :
	var main = Utils.get_scene_node()
	if main == null or not main.has_method("add_explosion"):
		return

	var fire_zone_scene = load(FENGLIU_FIRE_ZONE_SCENE_PATH)
	if fire_zone_scene == null:
		return

	# 爆炸实际半径 = 爆炸碰撞形状半径 × 爆炸实例缩放（已含「爆炸范围」属性）
	var explosion_radius: float = 147.34
	if is_instance_valid(explosion) and explosion.has_method("set_area"):
		var hitbox = explosion.get_node_or_null("Hitbox")
		if hitbox != null and hitbox._collision.shape is CircleShape2D:
			explosion_radius = hitbox._collision.shape.radius * explosion.scale.x

	var fire_zone = fire_zone_scene.instance()
	# 挂在 Main 下、紧跟地面 TileMap：位于地面之上、所有单位与特效之前（角色与敌人压在火圈之上）
	main.add_child(fire_zone)
	var ground = main.get_node_or_null("TileMap")
	if ground != null:
		main.move_child(fire_zone, ground.get_index() + 1)
	fire_zone.global_position = args.pos
	fire_zone.init_fire(args.burning_data, args.from_player_index, explosion_radius * effect.fire_scale, effect.fire_duration, effect.fire_tick_interval, effect.fire_particle_count)


# 在爆点生成水洼：半径按爆炸实际半径换算，潮湿时长与刷新间隔取效果值
func fengliu_spawn_water_zone(effect, args: WeaponServiceExplodeArgs, explosion: Node) -> void :
	var main = Utils.get_scene_node()
	if main == null:
		return

	var water_zone_scene = load(FENGLIU_WATER_ZONE_SCENE_PATH)
	if water_zone_scene == null:
		return

	# 爆炸实际半径 = 爆炸碰撞形状半径 × 爆炸实例缩放（已含「爆炸范围」属性）
	var explosion_radius: float = 147.34
	if is_instance_valid(explosion) and explosion.has_method("set_area"):
		var hitbox = explosion.get_node_or_null("Hitbox")
		if hitbox != null and hitbox._collision.shape is CircleShape2D:
			explosion_radius = hitbox._collision.shape.radius * explosion.scale.x

	var water_zone = water_zone_scene.instance()
	# 形状必须在入树前设置，否则物理区不会按新半径注册
	water_zone.init_water(
		explosion_radius * effect.puddle_scale,
		effect.puddle_duration,
		effect.wet_duration,
		effect.wet_tick_interval,
		null,
		ProgressData.settings.explosion_opacity)

	# 挂在 Main 下、紧跟地面 TileMap：位于地面之上、所有单位与特效之前
	main.add_child(water_zone)
	var ground = main.get_node_or_null("TileMap")
	if ground != null:
		main.move_child(water_zone, ground.get_index() + 1)
	water_zone.global_position = args.pos


# 中继器攻速：数据挂在构筑物实例的 meta 上，避免依赖 Structure 扩展是否进入继承链
const FENGLIU_RELAY_META_KEY = "fengliu_relay_attack_speed_sources"


# 中继器：登记一座中继器给出的攻速加成
func fengliu_set_relay_attack_speed(structure: Object, source: Object, percent: int) -> void:
	var sources: Dictionary = structure.get_meta(FENGLIU_RELAY_META_KEY, {})
	sources[source] = percent
	structure.set_meta(FENGLIU_RELAY_META_KEY, sources)


# 中继器：撤销一座中继器给出的加成（构筑物离开区域时调用）
func fengliu_clear_relay_attack_speed(structure: Object, source: Object) -> void:
	if not structure.has_meta(FENGLIU_RELAY_META_KEY):
		return
	var sources: Dictionary = structure.get_meta(FENGLIU_RELAY_META_KEY)
	sources.erase(source)
	structure.set_meta(FENGLIU_RELAY_META_KEY, sources)


# 当前累计的中继器攻速加成（%）；顺手剔除已释放的来源（中继器被摧毁无需回调）
func fengliu_get_relay_attack_speed_percent(structure: Object) -> int:
	if not structure.has_meta(FENGLIU_RELAY_META_KEY):
		return 0

	var sources: Dictionary = structure.get_meta(FENGLIU_RELAY_META_KEY)
	var total: int = 0
	for source in sources.keys():
		if not is_instance_valid(source):
			sources.erase(source)
			continue
		total += int(sources[source])

	return total


# 把中继器加成叠加到一个攻击间隔上（0 加成时原样返回）
func fengliu_apply_relay_attack_speed_to_cooldown(structure: Object, base_cooldown: int) -> int:
	var percent: int = fengliu_get_relay_attack_speed_percent(structure)
	if percent == 0:
		return base_cooldown

	return apply_attack_speed_mod_to_cooldown(base_cooldown, percent / 100.0)