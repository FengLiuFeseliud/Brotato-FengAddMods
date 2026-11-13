extends "res://dlcs/dlc_2/dlc_2_data.gd"


const FENGLIU_MECA_STAT_SET_ID := "fengliu"

#  mod 属性机械属性分类
var fengliu_meca_stats: Dictionary = {
	"stat_fengliu_shield": MecaStatCategory.DEFENSE,
}


func _get_allowed_meca_stats(player_index: int) -> Dictionary:
	_fengliu_refresh_meca_stats()
	return ._get_allowed_meca_stats(player_index)


func _fengliu_refresh_meca_stats() -> void:
	var has_set: bool = ProgressData.has_item_set(FENGLIU_MECA_STAT_SET_ID)

	for stat_name in fengliu_meca_stats:
		var category: int = fengliu_meca_stats[stat_name]
		var stat_hash: int = Keys.generate_hash(stat_name)
		var stats: Array = meca_stat_categories.get(category, []).duplicate()
		var has_stat: bool = stats.has(stat_hash)

		if has_set and not has_stat:
			stats.append(stat_hash)
			meca_stat_categories[category] = stats
		elif not has_set and has_stat:
			stats.erase(stat_hash)
			meca_stat_categories[category] = stats
