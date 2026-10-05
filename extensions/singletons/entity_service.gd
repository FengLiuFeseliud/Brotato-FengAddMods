extends "res://singletons/entity_service.gd"


func is_weapon_spawning_structure(weapon: WeaponData) -> bool:
	if .is_weapon_spawning_structure(weapon):
		return true

	for effect in weapon.effects:
		# 武器效果里存在构筑物效果即算会生成构筑物
		if effect is StructureEffect and effect.scene != null:
			return true

	return false
