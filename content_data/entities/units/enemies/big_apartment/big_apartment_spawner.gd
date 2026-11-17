extends Timer

# 大型居民楼脚本：定时召唤线条空间的小怪（走原版 enemy -> entity_spawner 生成链路；
# 本节点独立于 AttackBehavior，因为后者已被弹幕射击占用）
# 召唤规格：每 wait_time 秒一次（场景里设 2 秒）、每次随机 min_nb_to_spawn ~ max_nb_to_spawn 只（5 ~ 10）；
# 出生点在精英自身中心（spawn_radius = 0；大于 0 时才做小范围方形散布）；
# 对 Boss 仍按玩家「敌人数量」效果同比例放大（原版 Boss 规则）
export (Array, PackedScene) var enemies_to_spawn = []
export (int) var min_nb_to_spawn = 5
export (int) var max_nb_to_spawn = 10
export (int) var spawn_radius = 0


func _ready() -> void :
	# 反复触发，不手动 start
	one_shot = false
	if not is_connected("timeout", self, "_on_timeout"):
		var _error = connect("timeout", self, "_on_timeout")


func _on_timeout() -> void :
	var parent = get_parent()
	if parent == null or enemies_to_spawn.size() == 0:
		return

	var spawns: int = Utils.randi_range(min_nb_to_spawn, max_nb_to_spawn)
	if parent is Boss:
		spawns = int(max(1, round(spawns * (1.0 + RunData.sum_all_player_effects(Keys.number_of_enemies_hash) / 100.0))))

	# 每只独立随机一个候选小怪；位置在精英自身中心（spawn_radius 大于 0 时才散布）
	for i in spawns:
		var enemy_scene = enemies_to_spawn[randi() % enemies_to_spawn.size()]
		var pos = parent.global_position
		if spawn_radius > 0:
			pos += Vector2(rand_range( - spawn_radius, spawn_radius), rand_range( - spawn_radius, spawn_radius))
		parent._on_AttackBehavior_wanted_to_spawn_an_enemy(enemy_scene, pos)
