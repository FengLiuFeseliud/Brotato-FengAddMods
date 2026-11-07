extends "res://singletons/linked_stats.gd"


# 原版重算入口：先走原版，再按玩家结束本轮的 rebase 周期
func reset_player(player_index: int) -> void :
	.reset_player(player_index)
	_fengliu_apply_negative_nb_clamp(player_index)

	# 未加载 mod 扩展时静默跳过（缺接口不算错误）
	if has_method("fengliu_clear_rebase_pending"):
		call("fengliu_clear_rebase_pending", player_index)


# gain_stat_for_every_stat 的消费修正, 只在被缩放属性为负时生效
func _fengliu_apply_negative_nb_clamp(player_index: int) -> void :
	var effects: Dictionary = RunData.get_player_effects(player_index)
	var stat_links: Array = effects.get(Keys.stat_links_hash, [])

	if stat_links.empty():
		return

	var evolution: float = Utils.get_stat(Keys.stat_evolution_hash, player_index)
	var negative_only: float = max(0.0, - evolution)

	# 机械是正进化跳过
	if RunData.is_meca_only(player_index):
		negative_only = 0.0

	var fixes := {}

	for link in stat_links:
		if link == null or link.size() < 4:
			continue

		var nb_stat_scaled: int = int(link[3])

		if nb_stat_scaled >= 0 or int(link[2]) != Keys.stat_evolution_hash:
			continue

		var target_hash: int = int(link[0])
		var rate: float = float(link[1]) / abs(float(nb_stat_scaled))
		var base_added: int = int(float(link[1]) * evolution / float(nb_stat_scaled))
		var desired: int = int(rate * negative_only)
		fixes[target_hash] = int(fixes.get(target_hash, 0)) + desired - base_added

	for target_hash in fixes:
		var delta: int = int(fixes[target_hash])

		if delta == 0:
			continue

		effects[target_hash] = int(effects.get(target_hash, 0)) + delta

		# 父类路径解析到原版 temp_stats，台账方法只能动态调用（否则会累加）
		if has_method("_fengliu_add_ledger"):
			call("_fengliu_add_ledger", effects, target_hash, delta)

	Utils.reset_stat_cache(player_index)
