extends Structure


# 中继器攻速加成来源（来源节点 → 百分比）；同一构筑物被多座中继器覆盖时相加
var fengliu_relay_attack_speed_sources: Dictionary = {}


# 中继器：登记一座中继器给出的攻速加成
func fengliu_set_relay_attack_speed(source: Object, percent: int) -> void:
	fengliu_relay_attack_speed_sources[source] = percent


# 中继器：撤销一座中继器给出的加成（构筑物离开区域时调用）
func fengliu_clear_relay_attack_speed(source: Object) -> void:
	fengliu_relay_attack_speed_sources.erase(source)


# 当前累计的中继器攻速加成（%）；顺手剔除已释放的来源（中继器被摧毁无需回调）
func fengliu_get_relay_attack_speed_percent() -> int:
	var total: int = 0
	# 没有来源时直接返回，省掉字典遍历
	if fengliu_relay_attack_speed_sources.size() == 0:
		return total

	for source in fengliu_relay_attack_speed_sources.keys():
		if not is_instance_valid(source):
			fengliu_relay_attack_speed_sources.erase(source)
			continue
		total += int(fengliu_relay_attack_speed_sources[source])

	return total


# 把中继器加成叠加到一个攻击间隔上（0 加成时原样返回）
func fengliu_apply_relay_attack_speed_to_cooldown(base_cooldown: int) -> int:
	# 没有中继器加成时原样返回，避免无谓换算
	var percent: int = fengliu_get_relay_attack_speed_percent()
	if percent == 0:
		return base_cooldown

	return WeaponService.apply_attack_speed_mod_to_cooldown(base_cooldown, percent / 100.0)