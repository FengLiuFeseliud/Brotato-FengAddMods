extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/melee/melee_weapon.gd"


# ============================================================
# 普通的大剑（武器脚本）
#   特殊攻击（地裂斩 / 旋转扫击）已迁移到动作框架，
#   由场景的 actions 数组直接引用动作 .tres；本脚本只保留反弹子弹。
# ============================================================

# 反弹子弹（参考原版光剑）：命中敌方子弹时把它弹回最近的敌人
var _fengliu_deflect_stats: RangedWeaponStats = null
var _fengliu_deflect_args := WeaponServiceSpawnProjectileArgs.new()
var _fengliu_pending_deflects := []


func init_stats(at_wave_begin: bool = true) -> void:
	.init_stats(at_wave_begin)

	_fengliu_deflect_stats = null
	for effect in effects:
		if effect is DeflectProjectilesEffect and effect.weapon_stats != null:
			_fengliu_deflect_stats = WeaponService.init_ranged_stats(effect.weapon_stats, player_index, true)


# 能否反弹：敌方子弹、非旋转类、在树内、有池标记、还在飞、命中框有效
func _fengliu_is_deflectable(projectile) -> bool:
	return (
		is_instance_valid(projectile)
		and projectile is EnemyProjectile
		and not projectile is EnemyProjectileRotating
		and projectile.is_inside_tree()
		and projectile.has_meta("pool_id")
		and projectile.velocity != Vector2.ZERO
		and projectile._hitbox.active
	)


# 命中框扫到敌方子弹 ⇒ 延迟处理（物理回调里不直接改场景）
func _on_Hitbox_area_entered(area: Area2D) -> void:
	var projectile = area.get_parent()

	if not _fengliu_is_deflectable(projectile):
		return
	if _fengliu_pending_deflects.has(projectile):
		return

	_fengliu_pending_deflects.push_back(projectile)
	call_deferred("_fengliu_deflect", projectile)


# 反弹：停掉敌方子弹 → 朝最近敌人反射一发我方子弹 → 命中统计接回本武器
func _fengliu_deflect(projectile) -> void:
	_fengliu_pending_deflects.erase(projectile)

	if not _fengliu_is_deflectable(projectile):
		return

	var pos: Vector2 = projectile.global_position
	projectile.stop(true)

	if _fengliu_deflect_stats == null:
		return

	var target = _fengliu_get_nearest_enemy(pos)
	if target == null:
		return

	var direction: float = (Utils.get_target_position(target, pos) - pos).angle()
	_fengliu_deflect_args.deferred = true
	_fengliu_deflect_args.effects = []
	_fengliu_deflect_args.from_player_index = player_index
	_fengliu_deflect_args.knockback_direction = Vector2(cos(direction), sin(direction))

	var deflected = WeaponService.spawn_projectile(pos, _fengliu_deflect_stats, direction, self, _fengliu_deflect_args)
	if deflected == null or not is_instance_valid(deflected):
		return

	if not deflected.hit_something_connected:
		deflected.connect("hit_something", self, "on_weapon_hit_something", [deflected._hitbox])
		deflected.hit_something_connected = true


# 最近的活敌人（决定反弹方向）
func _fengliu_get_nearest_enemy(pos: Vector2):
	var main = Utils.get_scene_node()
	if main == null or not "_entity_spawner" in main or main._entity_spawner == null:
		return null

	var enemies := []
	for enemy in main._entity_spawner.get_all_enemies(false):
		if is_instance_valid(enemy) and not enemy.dead:
			enemies.push_back(enemy)

	return Utils.get_nearest_no_max(enemies, pos)[0]
