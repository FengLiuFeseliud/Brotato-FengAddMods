extends FloatingTextManager


# 与 HUD 盾条同色
const FENGLIU_SHIELD_TEXT_COLOR: = Color(0.25, 0.6, 1.0, 1.0)
# 蓝字上移一点，避免与红色生命伤害数字重叠
const FENGLIU_SHIELD_TEXT_OFFSET: = Vector2(0.0, -25.0)


# 盾吃下的部分显示蓝色数值 全吸收时不再跳0
func _on_unit_took_damage(unit: Unit, value: int, knockback_direction: Vector2, is_crit: bool, is_dodge: bool, is_protected: bool, armor_did_something: bool, args: TakeDamageArgs, hit_type: int, is_one_shot: bool) -> void :
	if is_dodge:
		._on_unit_took_damage(unit, value, knockback_direction, is_crit, is_dodge, is_protected, armor_did_something, args, hit_type, is_one_shot)
		return
	
	# 盾吸收量由玩家侧记录
	var absorbed: int = 0
	if unit is Player and unit.has_method("fengliu_consume_shield_absorb"):
		absorbed = unit.fengliu_consume_shield_absorb()

	if absorbed > 0 and ProgressData.settings.damage_display:
		display("-" + str(absorbed), unit.global_position + FENGLIU_SHIELD_TEXT_OFFSET, FENGLIU_SHIELD_TEXT_COLOR, null, duration, true, direction, false)

	# 盾吃下这一击时都不再走原版显示
	if value <= 0 and not is_protected:
		return

	._on_unit_took_damage(unit, value, knockback_direction, is_crit, is_dodge, is_protected, armor_did_something, args, hit_type, is_one_shot)


# 盾恢复：+x 蓝字（与盾吸收的 -x 同色同位；不看伤害数字开关，对齐原版回血）
func fengliu_on_player_shield_gained(value: int, player_index: int) -> void :
	if value <= 0 or player_index < 0 or player_index >= players.size():
		return

	display("+" + str(value), players[player_index].global_position + FENGLIU_SHIELD_TEXT_OFFSET, FENGLIU_SHIELD_TEXT_COLOR, null, duration, true, direction, false)
