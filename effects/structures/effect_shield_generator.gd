class_name ShieldGeneratorEffect
extends StructureEffect


# ============================================================
# 效果：护盾发生器（构筑物）
#   生成「护盾发生器」构筑物：区域内敌人按炮台攻击速度吃伤害，
#   区域内玩家按同一节奏回复 shield_regen 点护盾；打满
#   「close_after_attacks_base + 每 1 点工程学 × engineering_attack_rate」次后，
#   关闭区域并冷却 close_duration 秒（区域无人时不计次）。
#   被诅咒时由 RunData.fengliu_normalize_cursed_effect 按诅咒强度
#   放大区域范围（stats.max_range）与回盾量（shield_regen）。
#   运行时 effect id：fengliu_shield_generator（不使用 custom_key）
# ------------------------------------------------------------
# 效果值：
#   shield_regen              每次攻击给区域内玩家回复的护盾值
#   stats.max_range           区域半径（射程）
#   value                     生成数量
#   close_after_attacks_base  关闭前的基础攻击次数
#   engineering_attack_rate   每 1 点工程学增加的攻击次数比例
#   close_duration            关闭区域后的冷却时长（秒）
# ============================================================

export (int) var shield_regen: int = 1
export (int) var close_after_attacks_base: int = 5
export (float) var engineering_attack_rate: float = 0.1
export (float) var close_duration: float = 3.0

var _init_stats_args_shield: = WeaponServiceInitStatsArgs.new()


static func get_id() -> String:
	return "fengliu_shield_generator"


func get_args(player_index: int) -> Array:
	_init_stats_args_shield.effects = effects
	var init_stats = WeaponService.init_structure_stats(stats, player_index, _init_stats_args_shield)
	var engineering: float = Utils.get_stat(Keys.stat_engineering_hash, player_index)
	var attacks_before_close: int = max(1, close_after_attacks_base + int(engineering * engineering_attack_rate))

	return [
		str(init_stats.damage),
		str(shield_regen),
		str(attacks_before_close),
		str(int(close_duration)),
		WeaponService.get_scaling_stats_icon_text(init_stats.scaling_stats),
		Utils.get_scaling_stat_icon_text(Keys.stat_engineering_hash, engineering_attack_rate)
	]


func serialize() -> Dictionary:
	var serialized = .serialize()
	serialized.shield_regen = shield_regen
	serialized.close_after_attacks_base = close_after_attacks_base
	serialized.engineering_attack_rate = engineering_attack_rate
	serialized.close_duration = close_duration
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	if serialized.has("shield_regen"):
		shield_regen = serialized.shield_regen
	if serialized.has("close_after_attacks_base"):
		close_after_attacks_base = serialized.close_after_attacks_base
	if serialized.has("engineering_attack_rate"):
		engineering_attack_rate = serialized.engineering_attack_rate
	if serialized.has("close_duration"):
		close_duration = serialized.close_duration
