extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果基类：低于生命阈值触发
#   玩家生命比例 <= hp_threshold_pct 时执行一次子类操作；
#   回血到阈值以上后重新武装，再次掉到阈值以下会再触发；
#   once_per_wave = true 时同一波最多触发一次（换波自动解除）。
#   子类只需实现 fengliu_below_hp_execute(player_index)。
#   运行时槽位：fengliu_below_hp（所有该基类效果共用同一槽）
# ------------------------------------------------------------
# 约定：
#   基类不定义 get_id()，ItemService 会自动跳过（不登记为读档原型）；
#   子类必须自带 get_id()（返回 fengliu_ 前缀的唯一 id）；
#   .tres 的 custom_key 填 fengliu_below_hp，槽位初始化才对得上。
# ============================================================

const FENGLIU_BELOW_HP_SLOT_KEY := "fengliu_below_hp"

# 血量阈值（百分比，0~100，达到或低于即触发）
export(float, 0.0, 100.0) var hp_threshold_pct := 30.0
# 同一波内最多触发一次
export(bool) var once_per_wave := false

# 运行态（非导出字段，不写存档）
var _fengliu_below_hp_active := false
var _fengliu_below_hp_triggered_active := false
var _fengliu_below_hp_last_wave := -1
var _fengliu_below_hp_fired_wave := -1


# 槽位初始值：数组，供 ItemService 预建槽位
func fengliu_get_effect_init_value():
	return []


func apply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	var slot_hash: int = Keys.generate_hash(FENGLIU_BELOW_HP_SLOT_KEY)
	# 老存档可能没有这个槽，先补空数组
	if not effects.has(slot_hash) or not (effects[slot_hash] is Array):
		effects[slot_hash] = []
	if not effects[slot_hash].has(self):
		effects[slot_hash].push_back(self)


func unapply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	var slot_hash: int = Keys.generate_hash(FENGLIU_BELOW_HP_SLOT_KEY)
	if not effects.has(slot_hash) or not (effects[slot_hash] is Array):
		return
	effects[slot_hash].erase(self)


# 子类实现：低于阈值时要执行的操作
func fengliu_below_hp_execute(_player_index: int) -> void:
	pass


# 子类可选实现：回血到阈值以上 / 波末退出低血量状态时调用
# （用于撤销低血量期间的临时加成；不需要则不用覆写）
func fengliu_below_hp_on_exit(_player_index: int) -> void:
	pass


# 由玩家扩展每物理帧调用：health_ratio = 当前生命 / 最大生命 * 100
func fengliu_below_hp_tick_state(player_index: int, health_ratio: float) -> void:
	_fengliu_below_hp_sync_wave(player_index)

	if health_ratio <= hp_threshold_pct:
		# 已经处于低血量状态：只在进入时触发一次
		if _fengliu_below_hp_active:
			return

		_fengliu_below_hp_active = true
		# 本波已触发过：只保持 active，不再执行
		if once_per_wave and _fengliu_below_hp_fired_wave == RunData.current_wave:
			return

		_fengliu_below_hp_fired_wave = RunData.current_wave
		# 记录本次进入确实执行过，保证 on_exit 与 execute 成对
		_fengliu_below_hp_triggered_active = true
		fengliu_below_hp_execute(player_index)
		return

	# 回血到阈值以上：解除 active，下次掉下来可以再触发
	if not _fengliu_below_hp_active:
		return

	_fengliu_below_hp_active = false
	# 本次进入被 once_per_wave 拦截过就不算执行，不能回调 exit
	if not _fengliu_below_hp_triggered_active:
		return

	_fengliu_below_hp_triggered_active = false
	fengliu_below_hp_on_exit(player_index)


# 波末 / 死亡强制退出：清理状态并触发 exit
func fengliu_below_hp_force_reset(player_index: int) -> void:
	if _fengliu_below_hp_active:
		_fengliu_below_hp_active = false
		if _fengliu_below_hp_triggered_active:
			_fengliu_below_hp_triggered_active = false
			fengliu_below_hp_on_exit(player_index)

	_fengliu_below_hp_last_wave = -1
	_fengliu_below_hp_fired_wave = -1


# 换波时清空 active 与「本波已触发」标记
func _fengliu_below_hp_sync_wave(player_index: int) -> void:
	var wave: int = RunData.current_wave
	if _fengliu_below_hp_last_wave == wave:
		return

	# 上一波结束时没有走 clean_up_room 的兜底：先退出低血量状态
	if _fengliu_below_hp_active:
		_fengliu_below_hp_active = false
		if _fengliu_below_hp_triggered_active:
			_fengliu_below_hp_triggered_active = false
			fengliu_below_hp_on_exit(player_index)

	_fengliu_below_hp_last_wave = wave
	_fengliu_below_hp_fired_wave = -1


func get_args(_player_index: int) -> Array:
	# {0} = 触发阈值百分比
	return [str(hp_threshold_pct)]


func get_args_tool() -> Array:
	return [str(hp_threshold_pct)]


func serialize() -> Dictionary:
	var serialized = .serialize()
	# 基类字段不会被 mod_effect 的「直接子类新增字段」逻辑收集，
	# 必须在这里显式写入存档
	serialized.hp_threshold_pct = hp_threshold_pct
	serialized.once_per_wave = once_per_wave
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	if serialized.has("hp_threshold_pct"):
		hp_threshold_pct = float(serialized.hp_threshold_pct)
	if serialized.has("once_per_wave"):
		once_per_wave = bool(serialized.once_per_wave)
