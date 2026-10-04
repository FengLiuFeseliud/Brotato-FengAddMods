extends "res://singletons/entity_service.gd"


var weapon_claw_hammer_hash = Keys.generate_hash("weapon_claw_hammer")


# 覆盖：本 mod 的「羊角锤」效果会生成「护盾发生器」构筑物，同样算作会生成构筑物的武器
func is_weapon_spawning_structure(weapon: WeaponData) -> bool:
	return .is_weapon_spawning_structure(weapon) or weapon.weapon_id_hash == weapon_claw_hammer_hash
