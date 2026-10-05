class_name RelayEffect
extends StructureEffect


# ============================================================
# 效果：中继器（构筑物）
#   生成「中继器」构筑物：待在区域内的构筑物（炮台 / 护盾发生器…）获得额外的攻击速度，
#   攻速加成% ＝ (工程学 × engineering_scale + 攻击速度 × attack_speed_scale) × stat_scale_multiplier
#   + attack_speed_percent（下限 1）；多座中继器覆盖同一目标时相加。
#   半径 ＝ area_percent × (1 + 区域属性加成% / 100)，区域属性加成% ＝
#   (工程学 × area_engineering_scale + 范围 × area_range_scale) × stat_scale_multiplier。
#   以上数值全部在 get_args 里计算（文案 {0}~{5}），构筑物也从同一处读取 ⇒ 显示与实战同源。
#   被诅咒时由本类 fengliu_apply_curse 按口径 3 放大：四个「每 1 点属性」系数
#   （engineering_scale / attack_speed_scale / area_engineering_scale / area_range_scale）
#   与基础值（attack_speed_percent / area_percent）各 ×(1 + 诅咒强度)；
#   stat_scale_multiplier 不参与（避免与系数重复放大）。
#   运行时 effect id：fengliu_relay（不使用 custom_key）
# ------------------------------------------------------------
# 效果值：
#   engineering_scale        每 1 点工程学给出的攻速加成（%）
#   attack_speed_scale       每 1 点攻击速度给出的攻速加成（%）
#   attack_speed_percent     基础攻速加成（%），默认 0
#   area_engineering_scale   每 1 点工程学给出的区域加成（%）
#   area_range_scale         每 1 点范围给出的区域加成（%）
#   area_percent             基础半径（默认 250）
#   stat_scale_multiplier    属性缩放倍率（默认 1.0，诅咒时放大）
#   value                    生成数量
# ============================================================

export (int) var attack_speed_percent: int = 0
export (float) var engineering_scale: float = 1.0
export (float) var attack_speed_scale: float = 0.5
export (int) var area_percent: int = 250
export (float) var area_engineering_scale: float = 1.0
export (float) var area_range_scale: float = 0.3
export (float) var stat_scale_multiplier: float = 1.0


static func get_id() -> String:
	return "fengliu_relay"


func get_args(player_index: int) -> Array:
	# 数值全部在这里算：文案 {0}~{5} 与构筑物读取的实战值同源
	var engineering: float = Utils.get_stat(Keys.stat_engineering_hash, player_index)
	var attack_speed: float = Utils.get_stat(Keys.stat_attack_speed_hash, player_index)
	var stat_range: float = Utils.get_stat(Keys.stat_range_hash, player_index)

	# {0} 攻速加成%（下限 1）
	var attack_bonus_percent: int = int(max(1, (engineering * engineering_scale + attack_speed * attack_speed_scale) * stat_scale_multiplier + attack_speed_percent))
	# {3} 最终半径（基础半径 × (1 + 区域属性加成%/100)）
	var area_radius: int = int(round(area_percent * (1.0 + (engineering * area_engineering_scale + stat_range * area_range_scale) * stat_scale_multiplier / 100.0)))

	return [
		"[color=lime]%s%%[/color]" % str(attack_bonus_percent),
		Utils.get_scaling_stat_icon_text(Keys.stat_engineering_hash, engineering_scale),
		Utils.get_scaling_stat_icon_text(Keys.stat_attack_speed_hash, attack_speed_scale),
		str(area_radius),
		Utils.get_scaling_stat_icon_text(Keys.stat_engineering_hash, area_engineering_scale),
		Utils.get_scaling_stat_icon_text(Keys.stat_range_hash, area_range_scale)
	]


# 诅咒放大
func fengliu_apply_curse(base_effect: Resource, curse_factor: float) -> void:
	# 只处理与未诅咒原型同一脚本的效果，避免误改别的效果
	if base_effect == null or base_effect.get_script() != get_script():
		return

	# 诅咒强度倍率（口径 3）：四个「每 1 点属性」系数与基础值各 ×(1 + 诅咒强度)；
	# stat_scale_multiplier 不参与，避免与系数重复放大
	var factor: float = 1.0 + curse_factor
	engineering_scale = base_effect.engineering_scale * factor
	attack_speed_scale = base_effect.attack_speed_scale * factor
	area_engineering_scale = base_effect.area_engineering_scale * factor
	area_range_scale = base_effect.area_range_scale * factor
	attack_speed_percent = int(ceil(base_effect.attack_speed_percent * factor))
	area_percent = int(ceil(base_effect.area_percent * factor))
	stat_scale_multiplier = base_effect.stat_scale_multiplier

	# 原版只放大伤害，这里补上效果自带射程（已不参与半径计算，仅作兼容）
	var new_stats = stats.duplicate()
	new_stats.max_range = int(ceil(base_effect.stats.max_range * factor))
	stats = new_stats