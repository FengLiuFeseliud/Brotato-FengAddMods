extends Timer

# 地铁站脚本
export (int) var min_health = 20
export (int) var max_health = 50
export (int) var nb_to_spawn = 1
export (int) var spawn_radius = 60

var _pool: Array = []
var _blacklist: Array = ["spawner.tscn", "bloated_spawner.tscn", "slasher_egg.tscn", "infected_slasher_egg.tscn", "evil_mob.tscn", "metro.tscn"]


func _ready() -> void :
	# 进树即建池，并挂上定时回调
	one_shot = false
	_build_pool()
	if not is_connected("timeout", self, "_on_timeout"):
		var _error = connect("timeout", self, "_on_timeout")


func _on_timeout() -> void :
	if _pool.size() == 0:
		_build_pool()
	var parent = get_parent()
	if parent == null or _pool.size() == 0:
		return

	for i in nb_to_spawn:
		var scene: PackedScene = _pool[randi() % _pool.size()]
		var pos: Vector2 = parent.global_position
		if spawn_radius > 0:
			pos += Vector2(rand_range( - spawn_radius, spawn_radius), rand_range( - spawn_radius, spawn_radius))
		parent._on_AttackBehavior_wanted_to_spawn_an_enemy(scene, pos)


# 遍历所有区域的波次数据，收集候选敌人场景
func _build_pool() -> void :
	_pool = []
	var scenes: Array = []
	for zone in ZoneService.zones:
		if zone == null:
			continue
		if zone.waves_data != null:
			for wave in zone.waves_data:
				if wave == null:
					continue
				_add_groups(wave.groups_data, scenes)
				for conditional in wave.conditional_groups_data:
					_add_groups(conditional, scenes)
		_add_groups(zone.groups_data_in_all_waves, scenes)
		_add_groups(zone.horde_groups, scenes)
		_add_groups(zone.loot_alien_groups, scenes)
		_add_scenes(zone.endless_enemy_scenes, scenes)
		_add_scenes(zone.endless_nightmare_enemy_scenes, scenes)

	for scene in scenes:
		if _is_valid_summon(scene):
			_pool.append(scene)


func _add_groups(groups: Array, scenes: Array) -> void :
	# 从一组「组」数据里收集单位场景，去重后并入候选表
	if groups == null:
		return
	for group in groups:
		if group == null:
			continue
		for unit in group.wave_units_data:
			if unit == null or unit.unit_scene == null:
				continue
			if not scenes.has(unit.unit_scene):
				scenes.append(unit.unit_scene)


func _add_scenes(p_scenes: Array, scenes: Array) -> void :
	# 从场景数组里收集（区域的「无尽模式」敌人表）
	if p_scenes == null:
		return
	for scene in p_scenes:
		if scene != null and not scenes.has(scene):
			scenes.append(scene)


# 过滤：血量在区间内、会移动
func _is_valid_summon(scene: PackedScene) -> bool:
	# 三重过滤：血量落在区间内、会移动
	if scene == null:
		return false
	if _blacklist.has(scene.resource_path.get_file()):
		return false
	var stats: Resource = _get_scene_stats(scene)
	if stats == null:
		return false
	var speed = stats.get("speed")
	var health = stats.get("health")
	if speed == null or health == null or speed <= 0:
		return false
	return health >= min_health and health <= max_health


# 从场景状态里直接读根节点的 stats（不实例化场景）
func _get_scene_stats(scene: PackedScene) -> Resource:
	# 按属性名在根节点属性表里找 stats，避免实例化整个场景
	var state: SceneState = scene.get_state()
	if state.get_node_count() <= 0:
		return null
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == "stats":
			return state.get_node_property_value(0, i)
	return null
