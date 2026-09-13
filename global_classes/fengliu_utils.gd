class_name FengLiuUtils
extends Reference


# ============================================================
# 通用工具
#   仅 static、无状态（Godot 3.6 不支持 static var）
# ------------------------------------------------------------
#   随机值：范围内随机、按属性增益放大
#   概率：动态概率（百分比 / 0~1 比率）
#   效果载荷：Effect.apply / unapply 的统一读写
#   道具统计：统计玩家持有指定道具数量
#   场景：主场景与实体生成器
#   掉落：掉落一个消耗品
#   文本：绿色数值文本
#   常量：需要重新随机预报的效果
# ============================================================


# ============================================================
# 随机值
# ============================================================

# 随机生成动态值（范围内随机，可要求不为 0）
static func get_dynamic_value(stat_min_value: int, stat_max_value: int, stat_no_zero: bool) -> int:
	# 范围内随机取值
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	# 为 0 时重新取值
	if dynamic_value == 0 and stat_no_zero:
		return get_dynamic_value(stat_min_value, stat_max_value, stat_no_zero)
	return dynamic_value


# 计算动态值倍率（按属性增益放大）
static func get_dynamic_value_from_gain(dynamic_value: int, stat_gain: int, stat_gain_value: int) -> int:
	# 按属性增益放大
	return dynamic_value * (1 + (int(stat_gain / stat_gain_value)))


# 计算效果动态值（effect = [key_hash, min, max, no_zero, gain_stat_hash, gain_value]）
static func get_dynamic_value_from_effect(effect: Array, player_index: int) -> int:
	# 无增益直接随机
	if effect[5] == 0:
		return get_dynamic_value(effect[1], effect[2], effect[3])

	# 按属性增益放大随机值
	return int(get_dynamic_value_from_gain(get_dynamic_value(effect[1], effect[2], effect[3]), RunData.get_stat(effect[4], player_index), effect[5]))


# ============================================================
# 概率
# ============================================================

# 计算动态概率（返回 0~100 的百分比整数）
static func get_dynamic_chance(init_chance: int, add_chance: int, stat_count: int) -> int:
	# 基础概率 + 属性数 * 每点加成
	var dynamic_chance = int(init_chance + (stat_count * (add_chance / 100.0)))
	# 上限 100
	if dynamic_chance > 100:
		return 100

	return dynamic_chance


# 计算动态概率（返回 0~1 的浮点概率，供 Utils.get_chance_success 使用）
static func get_dynamic_chance_ratio(init_chance: int, add_chance: int, stat_count: int) -> float:
	# 基础概率 + 属性数 * 每点加成
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	# 上限 100
	if dynamic_chance > 100:
		return 100 / 100.0

	return dynamic_chance / 100.0


# 刷新效果动态概率（effect = [key_hash, value, chance, ..., stat_hash, add_chance]）
static func refresh_effect_chance(effect: Array, player_index: int) -> Array:
	# 根据属性刷新概率
	var stat = Utils.get_stat(effect[4], player_index)
	effect[2] = get_dynamic_chance(effect[-1], effect[-2], stat)
	return effect


# ============================================================
# 效果载荷（Effect.apply / unapply 统一读写）
# ============================================================

# 挂载效果载荷到玩家效果表
static func bind_effect(custom_key_hash: int, player_index: int, payload) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back(payload)


# 从玩家效果表移除效果载荷
static func unbind_effect(custom_key_hash: int, player_index: int, payload) -> void:
	var effects = RunData.get_player_effects(player_index)
	# 未挂载过则跳过，避免空 Key 报错
	if not effects.has(custom_key_hash):
		return

	effects[custom_key_hash].erase(payload)


# ============================================================
# 道具统计
# ============================================================

# 统计指定道具在道具列表中的数量
static func count_items(items: Array, item_hash: int) -> int:
	var count = 0
	# 统计指定道具数量
	for item in items:
		if item.my_id_hash == item_hash:
			count += 1
	return count


# 统计玩家持有指定道具数量
static func count_player_items(item_hash: int, player_index: int) -> int:
	return count_items(RunData.get_player_items(player_index), item_hash)


# ============================================================
# 场景
# ============================================================

# 当前主场景
static func get_main() -> Node:
	return Utils.get_scene_node()


# 当前主场景的实体生成器
static func get_entity_spawner():
	var main = get_main()
	if main == null:
		return null

	return main.get("_entity_spawner")


# ============================================================
# 掉落
# ============================================================

# 掉落一个消耗品（优先取对象池，池中没有则新建）
#   消耗品数据二选一：直接传 consumable_data，或传 tier 让本方法在取到实例后再生成
static func spawn_consumable(consumable_data, spawn_pos: Vector2, min_dist: float = 50.0, max_dist: float = 500.0, tier: int = -1):
	var main = get_main()
	if main == null:
		return

	# 从对象池取消耗品
	var consumable = main.get_node_from_pool(main._consumable_pool_id, main._consumables_container)
	# 池中没有则新建
	if consumable == null:
		consumable = main.consumable_scene.instance()
		main._consumables_container.call_deferred("add_child", consumable)
		var _error = consumable.connect("picked_up", main, "on_consumable_picked_up")
		yield(consumable, "ready")

	# 未直接给定数据时按品阶生成（保持与调用点一致的随机取值时机）
	if tier >= 0:
		consumable_data = ItemService.get_consumable_for_tier(tier)

	consumable.already_picked_up = false
	consumable.consumable_data = consumable_data
	consumable.set_texture(consumable_data.icon)

	# 随机距离与方向掉落
	var dist = rand_range(min_dist, max_dist)
	var push_back_destination = ZoneService.get_rand_pos_in_area(spawn_pos, dist, 0)
	consumable.drop(spawn_pos, 0, push_back_destination)

	main._consumables.push_back(consumable)


# ============================================================
# 文本（绿色数值）
# ============================================================

# 绿色数值
static func text_value(value) -> String:
	return "[color=lime]%s[/color]" % value


# 绿色百分比
static func text_percent(value) -> String:
	return "[color=lime]%s%%[/color]" % value


# 绿色 +数值
static func text_value_plus(value) -> String:
	return "[color=lime]+%s[/color]" % value


# 绿色 +百分比
static func text_percent_plus(value) -> String:
	return "[color=lime]+%s%%[/color]" % value


# ============================================================
# 常量
# ============================================================

# 需要重新随机预报的效果列表（商店与道具服务共用）
static func need_reroll_effects() -> Array:
	return [
		FengLiuKeys.effect_fengliu_swap_enemie(),
		FengLiuKeys.effect_fengliu_get_fixed_upgrade()
	]
