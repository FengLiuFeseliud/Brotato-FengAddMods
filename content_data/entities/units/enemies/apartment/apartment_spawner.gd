extends Timer

# 居民楼脚本：定时召唤敌人（走原版 enemy -> entity_spawner 生成链路；
# 本节点独立于 AttackBehavior，因为后者已被射击占用）
export (PackedScene) var enemy_to_spawn
export (int) var nb_to_spawn = 2
export (int) var spawn_radius = 60


func _ready() -> void :
	one_shot = false
	if not is_connected("timeout", self, "_on_timeout"):
		var _error = connect("timeout", self, "_on_timeout")


func _on_timeout() -> void :
	var parent = get_parent()
	if enemy_to_spawn == null or parent == null:
		return

	# 逐个生成：位置在自身周围小范围随机，其余交给原版生成链路
	for i in nb_to_spawn:
		var pos = parent.global_position
		if spawn_radius > 0:
			pos += Vector2(rand_range( - spawn_radius, spawn_radius), rand_range( - spawn_radius, spawn_radius))
		parent._on_AttackBehavior_wanted_to_spawn_an_enemy(enemy_to_spawn, pos)