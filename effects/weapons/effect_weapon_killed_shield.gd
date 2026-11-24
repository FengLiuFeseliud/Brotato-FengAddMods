class_name WeaponKilledShield
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_null_effect.gd"


# ============================================================
# 效果：武器击杀回盾
#   用该武器击杀敌人时，有概率直接回复玩家当前护盾；
#   只回复护盾，不加护盾上限，也不走属性增益。
#   运行时 custom_key：fengliu_weapon_killed_shield
# ------------------------------------------------------------
# 效果值：
#   key               概率倍率属性（提升触发概率所吃的属性）
#   value             基础触发概率（%）
#   gain_value        概率倍率（每 gain_value/100 点该属性 +1% 概率）
#   shield_value      每次触发回复的护盾值
#   shield_gain_stat  回盾量倍率属性（留空表示回盾量固定）
#   shield_gain_value 回盾量倍率（回盾量 += 该属性 × shield_gain_value/100）
# ============================================================

export (int) var gain_value = 0
export (int) var shield_value = 1
export (String) var shield_gain_stat = ""
export (int) var shield_gain_value = 0
var shield_gain_stat_hash = 0


static func get_id() -> String:
	return "fengliu_weapon_killed_shield"


func _generate_hashes() -> void:
	._generate_hashes()
	# 预生成回盾量倍率属性哈希
	shield_gain_stat_hash = Keys.generate_hash(shield_gain_stat)


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{3} 占位符：
	#   [0] = 动态触发概率百分比（绿色）
	#   [1] = 概率倍率属性图标文本
	#   [2] = 当前回盾量
	#   [3] = 回盾量倍率属性图标文本
	var dynamic_chance = value
	if key_hash != Keys.empty_hash:
		dynamic_chance += Utils.get_stat(key_hash, player_index) * (gain_value / 100.0)
	if dynamic_chance > 100:
		dynamic_chance = 100

	# 未配置概率倍率属性时退回纯数值
	var chance_scaling_text = str(gain_value / 100.0)
	if key_hash != Keys.empty_hash:
		chance_scaling_text = Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)

	# 首次取用时补算回盾量倍率属性哈希
	if shield_gain_stat_hash == 0 or shield_gain_stat_hash == Keys.empty_hash:
		shield_gain_stat_hash = Keys.generate_hash(shield_gain_stat)

	# 回盾量 = 基础值 + 属性 × 倍率；未配置倍率属性时只取基础值（避免对空键取属性）
	var shield = shield_value
	if shield_gain_stat_hash != Keys.empty_hash and shield_gain_value != 0:
		shield += int(Utils.get_stat(shield_gain_stat_hash, player_index) * (shield_gain_value / 100.0))

	# 回盾量倍率属性留空时不显示图标
	var shield_scaling_text = ""
	if shield_gain_stat_hash != Keys.empty_hash:
		shield_scaling_text = Utils.get_scaling_stat_icon_text(shield_gain_stat_hash, shield_gain_value / 100.0)

	return [
		str(dynamic_chance),
		chance_scaling_text,
		str(shield),
		shield_scaling_text
	]