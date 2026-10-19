extends Boss

# 大型居民楼脚本：异变（原版 boss 的 States 状态推进时触发，同时会弹出 MUTATION 浮字）
#   异变1（States/State1，索引 0）：一次性在整图随机位置召唤一批「小型居民楼」
#   异变2（States/State2，索引 1）：一次性在整图随机位置召唤一批「地铁站」
# boss.gd 传入的 new_state 是 States 子节点索引（从 0 开始）；以下导出是两段异变的调参口
export (PackedScene) var mutation_summon_scene
export (int) var mutation_summon_number = 7

export (PackedScene) var mutation2_summon_scene
export (int) var mutation2_summon_number = 10

var _fengliu_mutation_summoned: bool = false
var _fengliu_mutation2_summoned: bool = false


# 异变：按状态号分派，每段异变只召唤一次
func on_state_changed(new_state: int) -> void :
	.on_state_changed(new_state)

	if new_state == 0:
		if _fengliu_mutation_summoned:
			return
		_fengliu_mutation_summoned = true
		_fengliu_summon_random(mutation_summon_scene, mutation_summon_number)
	elif new_state == 1:
		if _fengliu_mutation2_summoned:
			return
		_fengliu_mutation2_summoned = true
		_fengliu_summon_random(mutation2_summon_scene, mutation2_summon_number)


# 整图随机位置召唤（等同原版 spawning_attack_behavior 的 spawn_at_random_pos）
func _fengliu_summon_random(scene: PackedScene, number: int) -> void :
	if scene == null or number <= 0:
		return

	for _index in number:
		_on_AttackBehavior_wanted_to_spawn_an_enemy(scene, ZoneService.get_rand_pos())
