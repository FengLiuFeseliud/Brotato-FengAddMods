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
	"fengliu_tree_drop_double",
	"fengliu_rekindling"
]


# 次要属性哈希列表缓存
var _fengliu_secondary_stats_hashs: Array = []


# 次要属性叠加台账（存在 effects 里、随存档走）：[{stat_hash, amount}]
# 台账必须可序列化，否则读档后台账丢失、链接层数值会被重复叠加（运动员 -5%/失效定向训练 就是这样变成负几百的）
var fengliu_secondary_ledger_key_hash: int = Keys.empty_hash


# 每个玩家「旧档 rebase」标记：台账缺失时只登记台账、不再回写，避免读档重复叠加
var _fengliu_rebase_pending: Array = [false, false, false, false]


# 懒生成台账键（Keys 先于本 autoload 加载；本实例按层取键：TempStats / LinkedStats 各一本）
func _fengliu_ensure_ledger_key() -> void :
	# 已生成则直接复用（哈希表由 RunData 持有，读写共用一份）
	if fengliu_secondary_ledger_key_hash == Keys.empty_hash:
		fengliu_secondary_ledger_key_hash = RunData.fengliu_secondary_ledger_key_hash(_fengliu_is_linked_stats_layer())


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


# 重置临时属性层：先按台账把链接层叠加量从 effects 回滚，再清理 TempStats 层
func reset_player(player_index: int) -> void :
	_fengliu_ensure_ledger_key()
	if player_index < RunData.players_data.size():
		var effects: Dictionary = RunData.get_player_effects(player_index)
		# 本次只登记台账不再追加，否则每次读档都会把链接层数值再叠一份
		var ledger_missing: bool = not effects.has(fengliu_secondary_ledger_key_hash)
		if _fengliu_revert_secondary_ledger(effects):
			are_player_stats_dirty[player_index] = true
			Utils.reset_stat_cache(player_index)
		# 立刻补回空台账：读档判定只看「键是否存在」，后续叠加恢复正常记账
		_fengliu_clear_secondary_ledger(effects)
		# 只有 StatLink 层的叠加量会随存档烘焙进 effects，所以旧档 rebase 只在 linked 层生效；
		# TempStats 层是波内临时量（原版会自行回收），无需 rebase，也不要消费 linked 层的标记
		if _fengliu_is_linked_stats_layer():
			var legacy_rebase: bool = RunData.fengliu_take_legacy_rebase(player_index)
			_fengliu_rebase_pending[player_index] = ledger_missing and legacy_rebase
		else:
			_fengliu_rebase_pending[player_index] = false

	.reset_player(player_index)

	# 非链接层（TempStats 自身）：本实例重置后没有后续重算循环，rebase 周期到此结束
	if not _fengliu_is_linked_stats_layer():
		_fengliu_rebase_pending[player_index] = false


# 清空全部 rebase 标记（新局/重开时 effects 全新重建，不存在需要 rebase 的烘焙值）
func reset() -> void :
	# 先清标记再走原版重置（原版会逐玩家调用 reset_player 重新判定）
	for index in _fengliu_rebase_pending.size():
		_fengliu_rebase_pending[index] = false
	.reset()


# 取出 effects 里的数值并归一化为 int
func _fengliu_as_int(value) -> int:
	# 整值浮点 / 数字字符串都归一化为 int，其余返回 0
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_integer():
		return int(value)
	return 0


# 把次要属性叠加量写进玩家 effects 字典，并登记可序列化台账
func _fengliu_apply_secondary_overlay(player_index: int, stat_hsh: int, delta: int) -> void :
	_fengliu_ensure_ledger_key()
	var effects: Dictionary = RunData.get_player_effects(player_index)
	# 旧档 rebase：现值已含一份，只登记台账、不回写
	if _fengliu_rebase_pending[player_index]:
		_fengliu_add_ledger(effects, stat_hsh, delta)
		return
	# 缺失时先归零；已有值（含读档后的 float）先归一化为 int 再累加
	if not effects.has(stat_hsh):
		effects[stat_hsh] = 0
	effects[stat_hsh] = _fengliu_as_int(effects[stat_hsh]) + delta
	_fengliu_add_ledger(effects, stat_hsh, delta)
	# 标记属性缓存失效
	are_player_stats_dirty[player_index] = true
	Utils.reset_stat_cache(player_index)


# 读取台账（JSON 往返后键与值可能是字符串/浮点，这里统一归一化为 int）
func _fengliu_get_secondary_ledger(effects: Dictionary) -> Dictionary:
	_fengliu_ensure_ledger_key()
	var ledger: Dictionary = {}
	# 无台账键 / 结构不符都视为空台账
	if not effects.has(fengliu_secondary_ledger_key_hash):
		return ledger
	var raw = effects[fengliu_secondary_ledger_key_hash]
	if not raw is Array:
		return ledger
	# 逐条归一化（键与值都可能是字符串/浮点）
	for entry in raw:
		if not entry is Array or entry.size() < 2:
			continue
		ledger[int(entry[0])] = int(entry[1])
	return ledger


# 写回台账（空台账也保留键：读档判定靠「键是否存在」区分新旧档）
func _fengliu_store_secondary_ledger(effects: Dictionary, ledger: Dictionary) -> void :
	# 只存非 0 项，统一写成 [stat_hash, amount] 数组
	var raw: Array = []
	for stat_hsh in ledger.keys():
		var amount: int = int(ledger[stat_hsh])
		if amount == 0:
			continue
		raw.push_back([int(stat_hsh), amount])
	effects[fengliu_secondary_ledger_key_hash] = raw


# 记一条台账增量
func _fengliu_add_ledger(effects: Dictionary, stat_hsh: int, delta: int) -> void :
	# 先读旧值再累加，避免同一次重算里多条目互相覆盖
	var ledger: Dictionary = _fengliu_get_secondary_ledger(effects)
	ledger[stat_hsh] = int(ledger.get(stat_hsh, 0)) + delta
	_fengliu_store_secondary_ledger(effects, ledger)


# 清空台账（保留键）
func _fengliu_clear_secondary_ledger(effects: Dictionary) -> void :
	# 写空数组而非 erase：键是否存在于读档判定里有意义
	_fengliu_ensure_ledger_key()
	effects[fengliu_secondary_ledger_key_hash] = []


# 按台账把链接层叠加量从 effects 减回去；返回是否真的回滚过
func _fengliu_revert_secondary_ledger(effects: Dictionary) -> bool:
	# 空台账无需回滚（旧档首次重算走 rebase 分支）
	var ledger: Dictionary = _fengliu_get_secondary_ledger(effects)
	if ledger.empty():
		return false
	# 只回滚本层记账过的部分；值可能是 float，统一按 int 处理
	for stat_hsh in ledger.keys():
		if not effects.has(stat_hsh):
			continue
		effects[stat_hsh] = _fengliu_as_int(effects[stat_hsh]) - int(ledger[stat_hsh])
	return true


# 当前实例是否为 StatLink 专用层：LinkedStats 与 TempStats 共用本扩展脚本，按 autoload 节点名区分
func _fengliu_is_linked_stats_layer() -> bool:
	return String(name) == "LinkedStats"


# 结束本玩家的 rebase 周期（由 LinkedStats 扩展在重算循环结束后调用）
func fengliu_clear_rebase_pending(player_index: int) -> void :
	# 越界索引直接忽略（假玩家 / coop 变更过程中可能出现）
	if player_index >= 0 and player_index < _fengliu_rebase_pending.size():
		_fengliu_rebase_pending[player_index] = false


# 扩展设置属性（次要属性叠加到 effects 层，其余走原逻辑）
func set_stat(stat_hsh: int, value: int, player_index: int) -> void :
	# 非次要属性交回原版逻辑
	if not _fengliu_is_secondary_stat(stat_hsh):
		.set_stat(stat_hsh, value, player_index)
		return
	# 只叠加与当前台账值的差值（台账即为「本层已叠加量」）
	var effects: Dictionary = RunData.get_player_effects(player_index)
	var ledger: Dictionary = _fengliu_get_secondary_ledger(effects)
	var current: int = int(ledger.get(stat_hsh, 0))
	_fengliu_apply_secondary_overlay(player_index, stat_hsh, value - current)


# 扩展增加属性（次要属性叠加到 effects 层）
func add_stat(stat_hsh: int, value: int, player_index: int) -> void :
	# 非次要属性交回原版逻辑
	if not _fengliu_is_secondary_stat(stat_hsh):
		.add_stat(stat_hsh, value, player_index)
		return

	# 叠加量由 _fengliu_apply_secondary_overlay 记进台账
	_fengliu_apply_secondary_overlay(player_index, stat_hsh, value)


# 扩展减少属性（次要属性从叠加层扣除）
func remove_stat(stat_hsh: int, value: int, player_index: int) -> void :
	# 次要属性从叠加层扣除，其余交给原版
	if not _fengliu_is_secondary_stat(stat_hsh):
		.remove_stat(stat_hsh, value, player_index)
		return

	_fengliu_apply_secondary_overlay(player_index, stat_hsh, -value)