extends "res://projectiles/bullet_enemy/enemy_projectile.gd"

# 直线一角鲸弹：slash 动画自带的 stop/disable_hitbox 只用于近战挥砍，
# 这里忽略它们，让弹体保持命中框并存活到 max_lifetime，从而获得远程射程。

export (float) var max_lifetime = 4.0

var _elapsed: float = 0.0
var _force_stopped: bool = false


func shoot() -> void:
	# 池化复用时重置计时与状态
	_elapsed = 0.0
	_force_stopped = false
	.shoot()


func _physics_process(delta: float) -> void:
	._physics_process(delta)
	if _force_stopped:
		return
	_elapsed += delta
	if _elapsed >= max_lifetime:
		_force_stop()


func stop() -> void:
	# slash 动画约 0.63s 调用的 stop：只结束动画，不回池
	pass


func disable_hitbox() -> void:
	# slash 动画约 0.6s 调用：远程弹体需要保持命中框
	pass


func _on_Hitbox_hit_something(_thing_hit: Node, _damage_dealt: int) -> void:
	# 命中时不要走被忽略的 stop()，直接强制回池
	_force_stop()


func on_entity_died(_entity: Entity, _args: Entity.DieArgs) -> void:
	_force_stop()


func _force_stop() -> void:
	if _force_stopped:
		return
	_force_stopped = true
	.stop()
