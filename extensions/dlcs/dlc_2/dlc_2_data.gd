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


# 本 mod 的 key-less 效果以 custom_key 作为唯一键：判定前临时借用 custom_key 的 hash，
# 使其能走完原版判定链（脚本声明 / 文本 / 正负号 / 上限 / 黑名单），原版 key-less 效果不受影响
func can_effect_be_copied_by_mutation(effect: Effect, player_index: int = - 1) -> bool:
	if effect != null and effect.key_hash == Keys.empty_hash and effect.custom_key != "" and effect.has_method("fengliu_can_be_copied_by_mutation"):
		var original_key_hash: int = effect.key_hash
		effect.key_hash = Keys.generate_hash(effect.custom_key)

		var result: bool = .can_effect_be_copied_by_mutation(effect, player_index)

		effect.key_hash = original_key_hash
		return result

	return .can_effect_be_copied_by_mutation(effect, player_index)


# 复制缩放：先走原版，再让效果返回值覆盖最终 value（无 bool、无副作用）
func _scale_copied_effect(effect: Effect, player_index: int) -> void:
	if effect == null:
		return

	var original_value: int = effect.value
	._scale_copied_effect(effect, player_index)

	if effect.has_method("fengliu_custom_mutation_scale"):
		effect.value = int(effect.call("fengliu_custom_mutation_scale", original_value, effect.value, player_index, self))

