extends Unit


var fengliu_rekindling = Keys.generate_hash("fengliu_rekindling")


func _on_BurningTimer_timeout() -> void:
	# 先取本跳数值：父类在末跳会把 _burning 置空
	var burning_ref: BurningData = _burning
	var echo_damage: int = burning_ref.damage if burning_ref != null else 0

	._on_BurningTimer_timeout()
	
	var rekindling: float = RunData.get_player_effect(fengliu_rekindling, _burning_player_index) / 100.0
	var can_rekindling_count = int(rekindling)
	var rekindlinge_chance = rekindling - can_rekindling_count

	# 无燃烧 / 伤害为 0 / 已死或正在死亡（父类这一跳已致死）→ 不补刀
	if echo_damage <= 0 or dead or _pending_die:
		return

	for _i in can_rekindling_count:
		take_damage(echo_damage, _take_damage_args_unit)

	if Utils.get_chance_success(rekindlinge_chance):
		take_damage(echo_damage, _take_damage_args_unit)
