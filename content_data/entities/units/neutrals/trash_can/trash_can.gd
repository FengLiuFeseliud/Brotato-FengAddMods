extends Neutral

# 垃圾桶：与树一样的可摧毁中立物；被摧毁时掉 1~4 个消耗品（出箱率更高，见 stats.item_drop_chance），
# 并额外放出 4 只「黑」（走原版生成队列，与波次刷怪同一链路）
export (int) var min_drops = 1
export (int) var max_drops = 3
export (PackedScene) var extra_enemy_scene
export (int) var extra_enemy_number = 4
export (float) var extra_enemy_spread = 60.0


func die(args: = Utils.default_die_args) -> void :
	# 已经死过就不再重复掉落（原版可能多次触发 die）
	if dead:
		return

	# 先走原版中立死亡链路（材料 / 统计）
	.die(args)

	# 死亡后补消耗品与「黑」，绕开原版只掉 1 个的限制
	_fengliu_drop_consumables()
	_fengliu_spawn_extra_enemies()


# 掉 1~4 个消耗品：逐个调用原版掉落链路，每个都会独立掷「果子 / 箱子」
func _fengliu_drop_consumables() -> void :
	var main = Utils.get_scene_node()
	if main == null or not main.has_method("spawn_consumables"):
		return

	# 1~4 个：每次独立走原版掉落链路（各自掷果子 / 箱子）
	var nb: int = Utils.randi_range(min_drops, max_drops)
	for i in nb:
		main.spawn_consumables(self)


# 额外放出 N 只小怪：塞进原版生成队列（EntityType.ENEMY），位置在自身周围抖动
func _fengliu_spawn_extra_enemies() -> void :
	if extra_enemy_scene == null or extra_enemy_number <= 0:
		return
	if _entity_spawner_ref == null:
		return

	# 逐只塞进生成队列，位置在自身周围抖动
	for i in extra_enemy_number:
		var offset: Vector2 = Vector2(rand_range( - extra_enemy_spread, extra_enemy_spread), rand_range( - extra_enemy_spread, extra_enemy_spread))
		_entity_spawner_ref.queue_to_spawn.push_back([EntityType.ENEMY, extra_enemy_scene, global_position + offset])
