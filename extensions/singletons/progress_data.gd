extends "res://singletons/progress_data.gd"


# 扩展存档：把波次强度统计附加到 run_state。
func get_run_state(
	shop_items: = [],
	reroll_count: = [],
	paid_reroll_count: = [],
	initial_free_rerolls: = [],
	free_rerolls: = [],
	item_steals: = []
) -> Dictionary:
	var run_state = .get_run_state(shop_items, reroll_count, paid_reroll_count, initial_free_rerolls, free_rerolls, item_steals)
	# 仅在进行中的对局附加，普通存档保持干净
	if run_state.get("has_run_state", false):
		RunData.fengliu_write_wave_intensity_state(run_state)
	return run_state
