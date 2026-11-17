extends "res://global/entity_spawner.gd"


const FENGLIU_CENTER_SPAWN_SCENE_FILE = "big_apartment.tscn"
const FENGLIU_RANDOM_INTERIOR_SPAWN_SCENE_FILE = "train_station.tscn"
const FENGLIU_RANDOM_INTERIOR_MARGIN_RATIO = 0.22


# 覆盖: 精英生成位置改写（大型居民楼 -> 正中；火车站 -> 场地中部随机点），其余实体照旧
func spawn_entity_birth(type: int, scene: PackedScene, pos: Vector2, data: Resource = null, player_index: = - 1, source = null, charmed_by: = - 1) -> void :
	# 出生点标记与本体共用改后的坐标
	if _fengliu_is_center_spawn(scene):
		pos = _fengliu_center_spawn_pos()
	elif _fengliu_is_random_interior_spawn(scene):
		pos = _fengliu_random_interior_spawn_pos()

	.spawn_entity_birth(type, scene, pos, data, player_index, source, charmed_by)


# 覆盖: 不经出生点标记的直调（调试菜单 / 效果生成的精英）同样改写位置
func spawn_entity(scene: PackedScene, args: EntitySpawner.SpawnEntityArgs, data: Resource = null, source = null, charmed_by: int = - 1) -> KinematicBody2D:
	# 队列生成已在上一步改过坐标，这里只兜住直调
	if args != null and _fengliu_is_center_spawn(scene):
		args.position = _fengliu_center_spawn_pos()
	elif args != null and _fengliu_is_random_interior_spawn(scene):
		args.position = _fengliu_random_interior_spawn_pos()

	return .spawn_entity(scene, args, data, source, charmed_by)


# 是否为本 mod 需要「固定居中生成」的场景
func _fengliu_is_center_spawn(scene: PackedScene) -> bool:
	# 场景资源缺失时按「不居中」处理
	if scene == null:
		return false

	return scene.resource_path.get_file() == FENGLIU_CENTER_SPAWN_SCENE_FILE


# 是否为本 mod 需要「场地中部随机点生成」的场景（十字铁轨四个方向都要留空间）
func _fengliu_is_random_interior_spawn(scene: PackedScene) -> bool:
	# 场景资源缺失时按「不特殊处理」处理
	if scene == null:
		return false

	return scene.resource_path.get_file() == FENGLIU_RANDOM_INTERIOR_SPAWN_SCENE_FILE


# 场地正中：等于原版 get_rand_pos_in_area_around_center() 用的 current_zone_max_position / 2
func _fengliu_center_spawn_pos() -> Vector2:
	return (_zone_min_pos + _zone_max_pos) / 2.0


# 场地中部随机点：四边各留 22% 余量
func _fengliu_random_interior_spawn_pos() -> Vector2:
	# 按场地尺寸算四边余量，再在内部随机取点
	var size: Vector2 = _zone_max_pos - _zone_min_pos
	var margin: Vector2 = size * FENGLIU_RANDOM_INTERIOR_MARGIN_RATIO
	return Vector2(
		rand_range(_zone_min_pos.x + margin.x, _zone_max_pos.x - margin.x),
		rand_range(_zone_min_pos.y + margin.y, _zone_max_pos.y - margin.y)
	)
