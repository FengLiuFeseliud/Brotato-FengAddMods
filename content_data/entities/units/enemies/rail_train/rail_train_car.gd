extends Enemy

# 列车车厢：位置由「火车站」每帧写入（自身移动行为用基类 movement_behavior，返回零向量）
# 死亡：在附近召唤 death_spawn_number 只线条空间小怪；撞击玩家：额外把玩家击飞

onready var life_bar: TextureProgress = $LifeBar

export (Array, PackedScene) var death_spawn_scenes = [
	preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/hei/hei.tscn"),
	preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/heiche/heiche.tscn"),
	preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/lan/lan.tscn"),
	preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/lanche/lanche.tscn"),
	preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/units/enemies/guihuo/guihuo.tscn"),
]
export (int) var death_spawn_number = 15
export (float) var death_spawn_radius = 180.0
export (float) var player_knockback_force = 700.0


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, players_ref, entity_spawner_ref)

	# 与 Boss.init 一致的早波血量 / 伤害减免
	if RunData.current_wave <= 8:
		max_stats.health = round(max_stats.health * 0.5) as int
		current_stats.health = max_stats.health
	elif RunData.current_wave <= 12:
		max_stats.health = round(max_stats.health * 0.75) as int
		current_stats.health = max_stats.health
		reset_damage_stat( - 25)

	if life_bar != null:
		if not ProgressData.settings.hp_bar_on_bosses:
			life_bar.hide()
		var _error_hp_lifebar = connect("health_updated", self, "on_health_updated")


func on_health_updated(_unit: Unit, current_val: int, max_val: int) -> void :
	# 与 Boss 相同的血条刷新规则（设置里关闭 Boss 血条时不显示）
	if life_bar == null:
		return

	if ProgressData.settings.hp_bar_on_bosses:
		if not life_bar.visible:
			life_bar.show()

		life_bar.update_value(current_val, max_val)
	elif life_bar.visible:
		life_bar.hide()


func die(args: = Utils.default_die_args) -> void :
	# 死亡时在附近召唤小怪（换波清场时不召唤，避免残留到场外）
	if not args.cleaning_up:
		_fengliu_spawn_death_enemies()

	.die(args)


func _fengliu_spawn_death_enemies() -> void :
	# 在自身周围随机角度 / 距离生成 death_spawn_number 只线条空间小怪
	if _entity_spawner_ref == null or death_spawn_scenes.size() == 0 or death_spawn_number <= 0:
		return

	for _index in death_spawn_number:
		var scene: PackedScene = death_spawn_scenes[randi() % death_spawn_scenes.size()]
		if scene == null:
			continue
		var angle: float = randf() * TAU
		var dist: float = rand_range(30.0, max(death_spawn_radius, 30.0))
		var spawn_pos: Vector2 = global_position + Vector2( cos(angle), sin(angle) ) * dist
		var spawn_args = EntitySpawner.SpawnEntityArgs.new(spawn_pos, EntityType.ENEMY)
		var _enemy = _entity_spawner_ref.spawn_entity(scene, spawn_args, null, self)


func _on_hit_something(thing_hit: Node, damage_dealt: int) -> void :
	# 撞到玩家：额外把玩家朝远离车身的方向击飞（三倍伤害由 stats 提供）
	if thing_hit is Player and player_knockback_force > 0.0:
		var push_dir: Vector2 = global_position.direction_to(thing_hit.global_position)
		thing_hit.knockback_vector = push_dir * player_knockback_force
		
	._on_hit_something(thing_hit, damage_dealt)
