extends "res://singletons/linked_stats.gd"


# 每个玩家的重算深度/待重算标记，防止 reset_player 在 add_stat 的调用栈里自我嵌套
var _fengliu_reset_depth: Dictionary = {}
var _fengliu_reset_pending: Dictionary = {}


# 满盾联动/属性钩子用：当前是否正在重算联动表
func fengliu_is_resetting(player_index: int) -> bool:
	return int(_fengliu_reset_depth.get(player_index, 0)) > 0


# 原版重算入口：先走原版，再按玩家结束本轮的 rebase 周期
func reset_player(player_index: int) -> void :
	# 已经处在重算栈里：只记账，等最外层重算结束后再补一次
	if fengliu_is_resetting(player_index):
		_fengliu_reset_pending[player_index] = true
		return

	# 先清理非法联动：4 项数组会让原版访问 [4] 越界，nb_stat_scaled=0 会除零
	_fengliu_sanitize_stat_links(player_index)

	_fengliu_reset_depth[player_index] = 1
	.reset_player(player_index)
	_fengliu_apply_negative_nb_clamp(player_index)
	_fengliu_reset_depth.erase(player_index)

	# 未加载 mod 扩展时静默跳过（缺接口不算错误）
	if has_method("fengliu_clear_rebase_pending"):
		call("fengliu_clear_rebase_pending", player_index)

	# 重算期间被压住的满盾联动，重算结束后只补一次
	if RunData.has_method("fengliu_request_full_shield_link"):
		RunData.fengliu_request_full_shield_link(player_index)

	# 重算期间又有嵌套 reset 请求：合并到下一帧执行
	if _fengliu_reset_pending.has(player_index):
		_fengliu_reset_pending.erase(player_index)
		call_deferred("reset_player", player_index)


# 清理会导致原版 LinkedStats.reset_player 越界/除零的联动条目
func _fengliu_sanitize_stat_links(player_index: int) -> void :
	var effects: Dictionary = RunData.get_player_effects(player_index)
	if not effects.has(Keys.stat_links_hash):
		return

	var stat_links = effects[Keys.stat_links_hash]
	if not (stat_links is Array):
		return

	for index in range(stat_links.size() - 1, -1, -1):
		var link = stat_links[index]

		if link == null or not (link is Array) or link.size() < 5:
			stat_links.remove(index)
			continue

		if int(link[3]) == 0:
			stat_links.remove(index)


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
