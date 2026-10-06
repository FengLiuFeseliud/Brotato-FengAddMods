class_name SentryTowerEffect
extends TurretEffect


# ============================================================
# 效果：哨戒塔（炮台构筑物）
#   生成「哨戒塔」：锁定目标后持续发射光束——每 stats.cooldown 一个节拍
#   （帧 ÷ 60 秒，含建筑攻速）对锁定目标造成一次 stats.damage，光束其余部分只作表现；锁定后只有目标死亡或
#   超出 [stats.min_range, stats.max_range] 才切换目标。
#   每造成一次伤害记 1 次攻击，累计 close_after_attacks_base +
#   每 1 点工程学 × engineering_attack_rate 次后，关闭光束 close_duration 秒
#   （期间不锁定、不伤害），随后重新锁定。
#   被诅咒时由本类 fengliu_apply_curse 放大攻击次数与射程（以未诅咒原型为基准）。
#   伤害记在 tracking_key 指向的道具行上（TurretEffect 口径，供伤害表/道具提示）。
#   运行时 effect id：fengliu_sentry_tower（不使用 custom_key）
# ------------------------------------------------------------
# 效果值：
#   close_after_attacks_base  关闭前的基础攻击次数
#   engineering_attack_rate   每 1 点工程学增加的攻击次数比例
#   close_duration            关闭时长（秒）
#   stats.max_range           光束长度（射程）
#   stats.damage              每次攻击的伤害
#   value                     生成数量
# ============================================================

export (int) var close_after_attacks_base: int = 5
export (float) var engineering_attack_rate: float = 0.2
export (float) var close_duration: float = 3.0


static func get_id() -> String:
	return "fengliu_sentry_tower"


func get_args(player_index: int) -> Array:
	_init_stats_args_turret.effects = effects
	var init_stats = WeaponService.init_structure_stats(stats, player_index, _init_stats_args_turret)
	var engineering: float = Utils.get_stat(Keys.stat_engineering_hash, player_index)
	# 攻击次数随工程学成长，下限 1 次
	var attacks_before_close: int = max(1, close_after_attacks_base + int(engineering * engineering_attack_rate))

	return [
		str(init_stats.damage),
		WeaponService.get_scaling_stats_icon_text(init_stats.scaling_stats),
		str(attacks_before_close),
		Utils.get_scaling_stat_icon_text(Keys.stat_engineering_hash, engineering_attack_rate),
		str(int(close_duration))
	]


func serialize() -> Dictionary:
	# 三个新增数值随效果一起存档（旧档缺字段时由反序列化补默认值）
	var serialized = .serialize()
	serialized.close_after_attacks_base = close_after_attacks_base
	serialized.engineering_attack_rate = engineering_attack_rate
	serialized.close_duration = close_duration
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	# 旧存档没有这些字段时保持默认值
	.deserialize_and_merge(serialized)
	if serialized.has("close_after_attacks_base"):
		close_after_attacks_base = serialized.close_after_attacks_base
	if serialized.has("engineering_attack_rate"):
		engineering_attack_rate = serialized.engineering_attack_rate
	if serialized.has("close_duration"):
		close_duration = serialized.close_duration


# 诅咒放大：攻击次数与射程按 (1 + 诅咒强度) 放大；以未诅咒原型为基准绝对赋值，重复调用不叠加
func fengliu_apply_curse(base_effect: Resource, curse_factor: float) -> void:
	# 只处理与未诅咒原型同一脚本的效果，避免误改别的效果
	if base_effect == null or base_effect.get_script() != get_script():
		return

	# 攻击次数与射程一起变强
	var factor: float = 1.0 + curse_factor
	close_after_attacks_base = int(ceil(base_effect.close_after_attacks_base * factor))
	var new_stats = stats.duplicate()
	new_stats.max_range = int(ceil(base_effect.stats.max_range * factor))
	stats = new_stats