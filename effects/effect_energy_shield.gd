class_name EnergyShieldEffect
extends StructureEffect


# ============================================================
# 效果：能量护盾（构筑物）
#   生成「能量护盾」构筑物：区域内敌人按炮台攻击速度吃伤害，
#   区域内玩家按同一节奏回复 shield_regen 点护盾。
#   被诅咒时由 RunData.fengliu_normalize_cursed_effect 按诅咒强度
#   放大区域范围（stats.max_range）与回盾量（shield_regen）。
#   运行时 effect id：fengliu_energy_shield（不使用 custom_key）
# ------------------------------------------------------------
# 效果值：
#   shield_regen     每次攻击给区域内玩家回复的护盾值
#   stats.max_range  区域半径（射程）
#   value            生成数量
# ============================================================

export (int) var shield_regen: int = 1


static func get_id() -> String:
	return "fengliu_energy_shield"


func serialize() -> Dictionary:
	# 基类字段照常，额外带上回盾量
	var serialized = .serialize()
	serialized.shield_regen = shield_regen
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	# 旧档缺失该字段时保留默认回盾量
	if serialized.has("shield_regen"):
		shield_regen = serialized.shield_regen
