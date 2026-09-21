extends "res://singletons/temp_stats.gd"


# 扩展：TempStats 支持次要属性


# 次要属性
const ALL_SECONDARY_STATS = [
	"consumable_heal",
	"xp_gain",
	"effect_pickup_range",
	"explosion_size",
	"explosion_damage",
	"effect_bouncing",
	"piercing",
	"piercing_damage",
	"damage_against_bosses",
	"structure_attack_speed",
	"structure_range",
	"burning_cooldown_reduction",
	"burning_spread",
	"knockback",
	"chance_double_gold",
	"free_rerolls",
	"trees",
	"number_of_enemies",

	"hp_start_wave",
	"hp_start_next_wave",

    "items_price",
	"reroll_price",

	"enemy_speed",
	"enemy_damage",
	"enemy_health",

    # 子弹缩放
    "fengliu_bullet_scale",
	"fengliu_tree_drop_double"
]


# 次要属性哈希列表缓存
var _fengliu_secondary_stats_hashs: Array = []


# 每个玩家已叠加到 effects 上的次要临时属性净值
var _fengliu_secondary_overlays: Array = [{}, {}, {}, {}]


# 懒生成次要属性哈希列表
func _fengliu_ensure_secondary_hashs_generated() -> void :
	# 已生成过则直接复用
	if _fengliu_secondary_stats_hashs.size() > 0:
		return
	for secondary_stat in ALL_SECONDARY_STATS:
		_fengliu_secondary_stats_hashs.append(Keys.generate_hash(secondary_stat))


# 判断是否为次要属性哈希
func _fengliu_is_secondary_stat(stat_hsh: int) -> bool:
	# 先确保哈希列表已生成
	_fengliu_ensure_secondary_hashs_generated()
	return _fengliu_secondary_stats_hashs.has(stat_hsh)


# 重置玩家临时属性：先还原 effects 基线，再清理 TempStats 层
func reset_player(player_index: int) -> void :
	if player_index < RunData.players_data.size():
		var overlay: Dictionary = _fengliu_secondary_overlays[player_index]
		if not overlay.empty():
			# 把临时叠加进 effects 的次要属性减回去，恢复永久基线
			var effects: Dictionary = RunData.get_player_effects(player_index)
			for stat_hsh in overlay.keys():
				if effects.has(stat_hsh):
					effects[stat_hsh] -= overlay[stat_hsh]
			overlay.clear()
			are_player_stats_dirty[player_index] = true
			Utils.reset_stat_cache(player_index)

	.reset_player(player_index)


# 把次要临时属性叠加量写进玩家 effects 字典
func _fengliu_apply_secondary_overlay(player_index: int, stat_hsh: int, delta: int) -> void :
	var effects: Dictionary = RunData.get_player_effects(player_index)
	# 缺失或类型不符时先归零
	if not effects.has(stat_hsh) or not effects[stat_hsh] is int:
		effects[stat_hsh] = 0
	effects[stat_hsh] += delta
	# 标记属性缓存失效
	are_player_stats_dirty[player_index] = true
	Utils.reset_stat_cache(player_index)


# 扩展设置属性（次要属性叠加到 effects 层，其余走原逻辑）
func set_stat(stat_hsh: int, value: int, player_index: int) -> void :
	# 非次要属性交回原版逻辑
	if not _fengliu_is_secondary_stat(stat_hsh):
		.set_stat(stat_hsh, value, player_index)
		return
	# 只叠加与当前值的差值
	var overlay: Dictionary = _fengliu_secondary_overlays[player_index]
	var current: int = overlay.get(stat_hsh, 0)
	_fengliu_apply_secondary_overlay(player_index, stat_hsh, value - current)
	overlay[stat_hsh] = value


# 扩展增加属性（次要属性叠加到 effects 层）
func add_stat(stat_hsh: int, value: int, player_index: int) -> void :
	# 非次要属性交回原版逻辑
	if not _fengliu_is_secondary_stat(stat_hsh):
		.add_stat(stat_hsh, value, player_index)
		return

	_fengliu_apply_secondary_overlay(player_index, stat_hsh, value)
	# 记录本次叠加量
	var overlay: Dictionary = _fengliu_secondary_overlays[player_index]
	overlay[stat_hsh] = overlay.get(stat_hsh, 0) + value


# 扩展减少属性（次要属性从叠加层扣除）
func remove_stat(stat_hsh: int, value: int, player_index: int) -> void :
	# 次要属性从叠加层扣除，其余交给原版
	if not _fengliu_is_secondary_stat(stat_hsh):
		.remove_stat(stat_hsh, value, player_index)
		return

	_fengliu_apply_secondary_overlay(player_index, stat_hsh, -value)
	var overlay: Dictionary = _fengliu_secondary_overlays[player_index]
	overlay[stat_hsh] = overlay.get(stat_hsh, 0) - value