extends "res://singletons/weapon_service.gd"


# 火圈场景：爆炸落点留下的燃烧地带
const FENGLIU_FIRE_ZONE_SCENE_PATH = "res://mods-unpacked/FengLiu-FengAddMods/projectiles/fire_zones/fire_zone.tscn"

# 按路径 preload 效果脚本：玩家版游戏不注册本 mod 自定义 class_name，只能用脚本对象比较
const FENGLIU_FIRE_EFFECT_SCRIPT = preload("res://mods-unpacked/FengLiu-FengAddMods/effects/weapons/effect_fire_exploding.gd")

var effect_fengliu_structure_add_range = Keys.generate_hash("fengliu_structure_add_range")


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