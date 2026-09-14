extends "res://singletons/weapon_service.gd"


var effect_fengliu_structure_add_range = Keys.generate_hash("fengliu_structure_add_range")


# 扩展构造物属性初始化（叠加全体玩家的射程加成）
func init_structure_stats(from_stats: RangedWeaponStats, player_index: int, args: WeaponServiceInitStatsArgs = _init_stats_args_service) -> RangedWeaponStats:
	var new_stats = .init_structure_stats(from_stats, player_index, args)

	# 累加全体玩家持有的“构造物射程”加成
	var bonus = 0
	for _p in RunData.get_player_count():
		var effects = RunData.get_player_effect(effect_fengliu_structure_add_range, _p)
		if effects.size() > 0:
			bonus += Utils.get_stat(effects[0][0], _p)

	# 有射程加成则叠加到最大射程
	if bonus > 0:
		new_stats.max_range = max(MIN_RANGE, new_stats.max_range + bonus)

	return new_stats
