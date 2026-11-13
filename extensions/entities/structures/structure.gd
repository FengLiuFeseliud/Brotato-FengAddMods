extends "res://entities/structures/structure.gd"


# 中继器接口：数据与换算统一在 WeaponService（late extension 不会进入原版 Turret 继承链）
func fengliu_set_relay_attack_speed(source: Object, percent: int) -> void:
	WeaponService.fengliu_set_relay_attack_speed(self, source, percent)


# 中继器：撤销一座中继器给出的加成（构筑物离开区域时调用）
func fengliu_clear_relay_attack_speed(source: Object) -> void:
	WeaponService.fengliu_clear_relay_attack_speed(self, source)


# 当前累计的中继器攻速加成（%）
func fengliu_get_relay_attack_speed_percent() -> int:
	return WeaponService.fengliu_get_relay_attack_speed_percent(self)


# 把中继器加成叠加到一个攻击间隔上（0 加成时原样返回）
func fengliu_apply_relay_attack_speed_to_cooldown(base_cooldown: int) -> int:
	return WeaponService.fengliu_apply_relay_attack_speed_to_cooldown(self, base_cooldown)