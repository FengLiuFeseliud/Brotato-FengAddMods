extends "res://singletons/utils.gd"


# 通用进化缩放 key：系数符号决定吃负进化还是正进化；其他武器/效果可直接在 scaling_stats 使用
const FENGLIU_EVOLUTION_SCALING_KEY := "fengliu_evolution_scaling"
var fengliu_evolution_scaling_hash = Keys.generate_hash(FENGLIU_EVOLUTION_SCALING_KEY)


func is_fengliu_evolution_scaling_key(stat_hsh: int) -> bool:
	return stat_hsh == fengliu_evolution_scaling_hash


# 通用进化缩放显示：系数符号决定显示正/负进化倍率
func get_scaling_stat_icon_text(stat_hsh: int, scaling: float = 1.0, show_plus_prefix: bool = true, color_override: String = "") -> String:
	if is_fengliu_evolution_scaling_key(stat_hsh):
		var w: float = 15 * ProgressData.settings.font_size
		var prefix: String = "+" if show_plus_prefix and scaling > 0.0 else ""
		var color: String = "white" if scaling > 0.0 else "#f6617c"
		if color_override != "":
			color = color_override
		var scaling_text: String = "[color=%s]%s%s%%[/color]" % [color, prefix, str(round(scaling * 100.0))]
		return "%s[img=%sx%s]%s[/img]" % [scaling_text, w, w, "res://items/stats/evolution.png"]

	return .get_scaling_stat_icon_text(stat_hsh, scaling, show_plus_prefix, color_override)


# 通用进化 ± 显示（用于进化 0 时合并 +x/-x）
func get_fengliu_evolution_pm_icon_text(scaling: float) -> String:
	var w: float = 15 * ProgressData.settings.font_size
	var scaling_text: String = "[color=white]±%s%%[/color]" % str(round(abs(scaling) * 100.0))
	return "%s[img=%sx%s]%s[/img]" % [scaling_text, w, w, "res://items/stats/evolution.png"]


# 通用泥潭尺寸：酸液池 / 机械泥潭 / 科技水枪共用
const FENGLIU_PUDDLE_SIZE_KEY := "fengliu_puddle_size"
var fengliu_puddle_size_hash = Keys.generate_hash(FENGLIU_PUDDLE_SIZE_KEY)


func get_fengliu_puddle_size_multiplier() -> float:
	return max(0.01, 1.0 + .sum_all_player_stats(fengliu_puddle_size_hash) / 100.0)


# 本 mod 的属性由物品套组注册
func reset_stat_keys() -> void:
	.reset_stat_keys()

	if ItemService.update_data_list == null:
		return

	for update_data in ItemService.update_data_list:
		if update_data == null or update_data.item_set == null:
			continue

		for set_stat in update_data.item_set.stats:
			if set_stat != null and not _stat_keys.has(set_stat.stat_hash):
				_stat_keys[set_stat.stat_hash] = 0
