extends "res://entities/units/unit/unit.gd"


var fengliu_rekindling = Keys.generate_hash("fengliu_rekindling")
var burning_slow_hash = Keys.generate_hash("fengliu_burning_slow")
var weapon_burn_damage_hash = Keys.generate_hash("fengliu_weapon_burn_damage")
var _fengliu_ignore_knockback_resistance_percent: int = 0
# 一次性燃烧跳伤倍数（冰冻联动用）：进入跳伤结算时立即读取并复位，避免泄漏到后续真实跳伤
var _fengliu_burn_tick_multiplier: float = 1.0


# 覆盖: 燃烧跳伤结算 → 多重燃烧补刀、燃烧伤害减速与武器燃烧伤害并入
func _on_BurningTimer_timeout() -> void:
	# 一次性跳伤倍数（冰冻联动用）：进入结算立刻读取并复位
	var tick_multiplier: float = _fengliu_burn_tick_multiplier
	_fengliu_burn_tick_multiplier = 1.0

	# 先取本跳数值：父类在末跳会把 _burning 置空
	var burning_ref: BurningData = _burning
	var burning_player_index: int = _burning_player_index

	var burn_damage_backup: int = _burning.damage if _burning != null else 0
	_fengliu_get_weapon_burn_damage(_burning, burning_player_index)

	# 先按「武器燃烧伤害总和」重算，再乘一次性倍数（多重燃烧按翻倍后的值补刀）
	if _burning != null and tick_multiplier != 1.0:
		_burning.damage = int(round(_burning.damage * tick_multiplier))

	var echo_damage: int = _burning.damage if _burning != null else 0

	._on_BurningTimer_timeout()

	if _burning != null:
		_burning.damage = burn_damage_backup

	# 燃烧伤害减速：本跳结算后按「燃烧减速」给目标叠加衰减减速
	if burning_ref != null and not dead and not _pending_die:
		_fengliu_apply_burning_slow(burning_player_index)
	
	var rekindling: float = RunData.get_player_effect(fengliu_rekindling, _burning_player_index) / 100.0
	var can_rekindling_count = int(rekindling)
	var rekindlinge_chance = rekindling - can_rekindling_count

	# 无燃烧 / 伤害为 0 / 已死或正在死亡（父类这一跳已致死）→ 不补刀
	if echo_damage <= 0 or dead or _pending_die:
		return

	for _i in can_rekindling_count:
		take_damage(echo_damage, _take_damage_args_unit)

	if Utils.get_chance_success(rekindlinge_chance):
		take_damage(echo_damage, _take_damage_args_unit)


# 武器燃烧伤害总和
func _fengliu_get_weapon_burn_damage(burning: BurningData, player_index: int) -> void:
	if burning == null:
		return

	var burn_damage_percent = RunData.get_player_effect(weapon_burn_damage_hash, player_index)

	# 未持有该效果则不生效
	if burn_damage_percent <= 0:
		return

	var total_burn_damage: int = 0
	for weapon_data in RunData.get_player_weapons_ref(player_index):
		if weapon_data == null:
			continue

		# 武器燃烧数据来自武器自身的「燃烧效果」
		for weapon_effect in weapon_data.effects:
			if not (weapon_effect is BurningEffect) or weapon_effect.burning_data == null:
				continue

			# 与武器燃烧效果提示同口径：按玩家属性折算后的燃烧伤害
			var burning_data: BurningData = weapon_effect.burning_data
			var is_structure: bool = burning_data.scaling_stats.size() > 0 and Utils.get_first_scaling_stat(burning_data.scaling_stats) == Keys.stat_engineering_hash
			total_burn_damage += WeaponService.init_burning_data(burning_data, player_index, is_structure).damage

	burning.damage = int(total_burn_damage * (burn_damage_percent / 100.0))


# 按「燃烧减速」效果给燃烧中的目标叠加衰减减速
func _fengliu_apply_burning_slow(player_index: int) -> void:
	var burning_slow_effects = RunData.get_player_effect(burning_slow_hash, player_index)

	for burning_slow_effect in burning_slow_effects:
		# 减速值 = 基础值 + 倍率属性 × gain_value/100
		var slow_value = burning_slow_effect[1] + int(Utils.get_stat(burning_slow_effect[0], player_index) * (burning_slow_effect[2] / 100.0))
		add_decaying_speed(-slow_value)


# 有效击退抗性：按攻击玩家的「无视击退抗性」次要属性忽略 value% 的抗性
func get_effective_knockback_resistance() -> float:
	if stats == null:
		return 0.0
		
	var ignore: int = int(clamp(_fengliu_ignore_knockback_resistance_percent, 0, 100))
	return stats.knockback_resistance * (1.0 - ignore / 100.0)


# 覆盖：击退速度使用有效抗性
func get_knockback_value() -> Vector2:
	return knockback_vector * (100.0 - get_effective_knockback_resistance() * 100.0)


# 覆盖：贯通击退使用有效抗性
func get_increased_piercing_knockback_amount(amount: float, piercing: float, _resistance: float) -> float:
	return .get_increased_piercing_knockback_amount(amount, piercing, get_effective_knockback_resistance())


# 冰冻联动 把一次「燃烧跳伤」完整走一遍燃烧结算链
func fengliu_settle_burn_tick(
	damage: int, player_index: int, from = null, scaling_stats: Array = [],
	is_global_burn: bool = false, tracking_key: String = "", multiplier: float = 2.0
) -> void:
	var can_tick: bool = damage > 0 and not dead and not _pending_die and player_index >= 0 and player_index < RunData.get_player_count()

	if can_tick:
		# 临时燃烧状态：duration=1 → 父类结算后自然走到 stop_burning()
		var data := BurningData.new()
		data.chance = 1.0
		data.damage = damage
		data.duration = 1
		data.spread = 0
		data.scaling_stats = scaling_stats.duplicate()
		data.is_global_burn = is_global_burn
		data.tracking_key = tracking_key
		# BurningData 的 _late_init 是 deferred，本帧取不到需要手动补
		data.tracking_key_hash = Keys.generate_hash(tracking_key)
		data.from = from

		_burnings = {SHARED_BURNING_SOURCE_ID: data.duplicate()}
		_burning = data
		_burning_player_index = player_index
		_fengliu_burn_tick_multiplier = multiplier
		_on_BurningTimer_timeout()

	# 取消原燃烧 / 清理临时状态（幂等）
	if _burning != null or _burnings.size() > 0:
		stop_burning()

	_fengliu_burn_tick_multiplier = 1.0

