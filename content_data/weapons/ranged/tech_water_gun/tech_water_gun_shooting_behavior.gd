extends "res://weapons/shooting_behaviors/ranged_weapon_shooting_behavior.gd"


# ============================================================
# 科技水枪：每发水弹按当前进化形态取 projectile 变体并染色
# ============================================================
func shoot_projectile(rotation: float = _parent.rotation, knockback: Vector2 = Vector2.ZERO) -> Node:
	var form: int = _parent.take_next_form()

	_ranged_spawn_projectile_args.knockback_direction = knockback
	_ranged_spawn_projectile_args.effects = _parent.effects
	_ranged_spawn_projectile_args.from_player_index = _parent.player_index

	var projectile = WeaponService.spawn_projectile(
		_parent.muzzle.global_position,
		_parent.get_projectile_stats(form),
		rotation,
		_parent,
		_ranged_spawn_projectile_args
	)

	if is_instance_valid(projectile):
		projectile.set_meta(_parent.PROJECTILE_FORM_META, form)
		_parent.apply_projectile_form(projectile, form)

	emit_signal("projectile_shot", projectile)
	return projectile
