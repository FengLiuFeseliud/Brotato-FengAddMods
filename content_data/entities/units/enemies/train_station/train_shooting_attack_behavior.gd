extends "res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd"

# 火车站 / 车厢共用：原版 ShootingAttackBehavior 在 current_target 为 null 时会在
# physics_process 里取 global_position 报错（玩家全灭 / 沙盒环境），这里先判空再交给基类


func physics_process(delta: float) -> void :
	# 没有目标时直接跳过，等下一帧再试
	if _parent == null or not is_instance_valid(_parent):
		return

	if _parent.current_target == null or not is_instance_valid(_parent.current_target):
		return
		
	.physics_process(delta)
