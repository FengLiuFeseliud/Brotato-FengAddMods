class_name ShieldGeneratorEffect
extends StructureEffect


# ============================================================
# 效果：护盾发生器（构筑物）
#   生成「护盾发生器」构筑物：区域内敌人按炮台攻击速度吃伤害，
#   区域内玩家按同一节奏回复 shield_regen 点护盾；打满
#   「close_after_attacks_base + 每 1 点工程学 × engineering_attack_rate」次后，
#   关闭区域并冷却 close_duration 秒（区域无人时不计次）。
#   被诅咒时由本类 fengliu_apply_curse 按诅咒强度放大区域范围（stats.max_range）
#   与回盾量（shield_regen）；伤害表要挂的道具行由 fengliu_get_damage_tracking_key 给出。
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

# 伤害追踪键的单一真相在构筑物脚本里，这里按路径取，避免两处字面量
const SHIELD_GENERATOR_SCRIPT = preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/structures/shield_generator/shield_generator.gd")

export (int) var shield_regen: int = 1
export (int) var close_after_attacks_base: int = 5
export (float) var engineering_attack_rate: float = 0.1
export (float) var close_duration: float = 3.0

var _init_stats_args_shield: = WeaponServiceInitStatsArgs.new()


static func get_id() -> String:
	return "fengliu_shield_generator"


# 本效果生成的构筑物把伤害记在哪个道具的追踪键上（空 = 不在第三方伤害表里挂道具行）
func fengliu_get_damage_tracking_key() -> String:
	return SHIELD_GENERATOR_SCRIPT.DAMAGE_TRACKING_KEY


# 诅咒放大（钩子，由 RunData.fengliu_normalize_cursed_effects 调用）：
# 区域半径与回盾量按 (1 + 诅咒强度) 放大；以未诅咒原型为基准绝对赋值，重复调用不叠加
func fengliu_apply_curse(base_effect: Resource, curse_factor: float) -> void:
	# 只处理与未诅咒原型同一脚本的效果，避免误改别的效果
	if base_effect == null or base_effect.get_script() != get_script():
		return

	# 诅咒强度倍率
	var factor: float = 1.0 + curse_factor
	shield_regen = int(ceil(base_effect.shield_regen * factor))

	# 原版只放大伤害，这里补上区域半径
	var new_stats = stats.duplicate()
	new_stats.max_range = int(ceil(base_effect.stats.max_range * factor))
	stats = new_stats


func get_args(player_index: int) -> Array:
	_init_stats_args_shield.effects = effects
	var init_stats = WeaponService.init_structure_stats(stats, player_index, _init_stats_args_shield)
	var engineering: float = Utils.get_stat(Keys.stat_engineering_hash, player_index)
	# 攻击次数随工程学成长，下限 1 次
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
	# 新增的 3 个数值一并存档（旧档缺字段时由反序列化补默认值）
	var serialized = .serialize()
	serialized.shield_regen = shield_regen
	serialized.close_after_attacks_base = close_after_attacks_base
	serialized.engineering_attack_rate = engineering_attack_rate
	serialized.close_duration = close_duration
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	# 旧存档没有这些字段时保持默认值
	.deserialize_and_merge(serialized)
	if serialized.has("shield_regen"):
		shield_regen = serialized.shield_regen
	if serialized.has("close_after_attacks_base"):
		close_after_attacks_base = serialized.close_after_attacks_base
	if serialized.has("engineering_attack_rate"):
		engineering_attack_rate = serialized.engineering_attack_rate
	if serialized.has("close_duration"):
		close_duration = serialized.close_duration
