class_name FogWaveChance
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：迷雾波概率
#   每波开始时按 value% 概率使本波进入迷雾状态（即下一波起生效）。
#   触发时按 stat_deductions 永久扣除属性（小数=按当前值百分比）。
#   运行时 custom_key：fengliu_fog_wave_chance
# ------------------------------------------------------------
# 效果值：
#   value            触发概率（%）
#   stat_deductions  触发时永久扣除的属性，格式 [[属性名, 扣除量], ...]
#                    扣除量绝对值 < 1（且非 0）= 按当前面板值百分比，否则=固定值
#                    负值 = 反向（增加）
# ============================================================

# 迷雾波概率

# 扣除说明使用的属性短名翻译键（原版 STAT_MAX_HP / STAT_SPEED 的显示不适合本描述）
const FENGLIU_DEDUCTION_STAT_NAME_KEYS := {
	"stat_max_hp": "STAT_MAX_HP_SHORT",
	"stat_speed": "STAT_SPEED_SHORT",
	"stat_armor": "STAT_ARMOR_SHORT"
}

export (Array) var stat_deductions = []


static func get_id() -> String:
	return "fengliu_fog_wave_chance"


# 数值累加 / 消费端遍历，异变复制有效
func fengliu_can_be_copied_by_mutation() -> bool:
	return true


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back([value, stat_deductions])


func unapply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).erase([value, stat_deductions])


func fengliu_get_effect_init_value():
	return []


# 按 [[属性名, 扣除量]] 永久扣除（供迷雾结算调用）
static func fengliu_apply_stat_deductions(deductions: Array, player_index: int) -> void:
	for entry in deductions:
		if entry == null or entry.size() < 2:
			continue

		var stat_hash = Keys.generate_hash(str(entry[0]))
		var raw_amount = float(entry[1])
		var applied = 0

		# 小数（绝对值 < 1）= 按当前面板值百分比扣除
		if raw_amount != 0.0 and abs(raw_amount) < 1.0:
			applied = int(ceil(Utils.get_stat(stat_hash, player_index) * raw_amount))
		else:
			applied = int(raw_amount)

		if applied == 0:
			continue

		_fengliu_add_stat_value(stat_hash, -applied, player_index)


# 主属性走 add_stat；其余属性直接写效果槽
static func _fengliu_add_stat_value(stat_hash: int, delta: int, player_index: int) -> void:
	if Utils.is_stat_key(stat_hash):
		RunData.add_stat(stat_hash, delta, player_index)
		return

	var effects = RunData.get_player_effects(player_index)
	var current = effects.get(stat_hash, 0)
	if not (current is int or current is float):
		current = 0
		
	effects[stat_hash] = current + delta
	Utils.reset_stat_cache(player_index)


# 扣除说明文本：10%最大生命, 1移速, 10%护甲
func fengliu_get_deductions_text() -> String:
	var parts = []
	for entry in stat_deductions:
		if entry == null or entry.size() < 2:
			continue

		var stat_id = str(entry[0])
		var raw_amount = float(entry[1])
		var stat_name = tr(FENGLIU_DEDUCTION_STAT_NAME_KEYS.get(stat_id, stat_id.to_upper()))
		var amount_text = ""

		# 小数按百分比显示（去掉多余的 0）
		if raw_amount != 0.0 and abs(raw_amount) < 1.0:
			amount_text = ("%.2f" % (abs(raw_amount) * 100)).rstrip("0").rstrip(".") + "%"
		else:
			amount_text = str(abs(raw_amount))

		if raw_amount < 0.0:
			amount_text = "+" + amount_text

		parts.push_back(amount_text + stat_name)

	return PoolStringArray(parts).join(", ")


func get_args(_player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{1} 占位符：
	#   [0] = 触发概率（百分号由 text.gd 的 keys_needing_percent 补）
	#   [1] = 触发时扣除说明（无扣除时为空）
	return [str(value), fengliu_get_deductions_text()]
