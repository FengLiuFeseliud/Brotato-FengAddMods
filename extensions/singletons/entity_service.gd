extends "res://singletons/entity_service.gd"


func is_weapon_spawning_structure(weapon: WeaponData) -> bool:
	if .is_weapon_spawning_structure(weapon):
		return true

	for effect in weapon.effects:
		# 武器效果里存在构筑物效果即算会生成构筑物
		if effect is StructureEffect and effect.scene != null:
			return true

	return false

# 覆盖：原版对炮台效果的 text_key 有白名单 assert；本 mod 新增的哨戒塔不在名单里，
# 这里改成「名单内按名次、名单外按字典序」兜底，避免 max_turret_count 流程断言失败
func sort_turrets_by_strength(a: TurretEffect, b: TurretEffect) -> bool:
	# 原版名次表（顺序不变）
	var ordering: = ["effect_builder_turret_alt", "effect_turret_rocket", "effect_turret_laser", "effect_tyler", "effect_turret_flame", "effect_turret", "effect_turret_healing"]
	var a_index: int = ordering.find(a.text_key)
	var b_index: int = ordering.find(b.text_key)

	# 名单外的效果（本 mod 新增）按字典序排在名单之后
	if a_index == -1 and b_index == -1:
		return a.text_key < b.text_key
	if a_index == -1:
		return false
	if b_index == -1:
		return true

	return a_index < b_index
