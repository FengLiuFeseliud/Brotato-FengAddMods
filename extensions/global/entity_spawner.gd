extends "res://global/entity_spawner.gd"


const FENGLIU_CENTER_SPAWN_SCENE_FILE = "big_apartment.tscn"


# 覆盖: 精英「大型居民楼」固定在场地正中生成（出生点标记与本体一起居中），其余实体照旧
func spawn_entity_birth(type: int, scene: PackedScene, pos: Vector2, data: Resource = null, player_index: = - 1, source = null, charmed_by: = - 1) -> void :
	# 需要居中的场景直接改写生成坐标（出生点标记也用它）
	if _fengliu_is_center_spawn(scene):
		pos = _fengliu_center_spawn_pos()

	.spawn_entity_birth(type, scene, pos, data, player_index, source, charmed_by)


# 覆盖: 不经出生点标记的直调（调试菜单 / 效果生成的精英）同样落到正中
func spawn_entity(scene: PackedScene, args: EntitySpawner.SpawnEntityArgs, data: Resource = null, source = null, charmed_by: int = - 1) -> KinematicBody2D:
	# 队列生成已在上一步改过坐标，这里只兜住直调
	if args != null and _fengliu_is_center_spawn(scene):
		args.position = _fengliu_center_spawn_pos()

	return .spawn_entity(scene, args, data, source, charmed_by)


# 是否为本 mod 需要「固定居中生成」的场景
func _fengliu_is_center_spawn(scene: PackedScene) -> bool:
	# 场景资源缺失时按「不居中」处理
	if scene == null:
		return false

	return scene.resource_path.get_file() == FENGLIU_CENTER_SPAWN_SCENE_FILE


# 场地正中：等于原版 get_rand_pos_in_area_around_center() 用的 current_zone_max_position / 2
func _fengliu_center_spawn_pos() -> Vector2:
	return (_zone_min_pos + _zone_max_pos) / 2.0
