class_name KnockbackOutOfMap
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：击退出地图
#   持有该效果时，武器命中把目标击退；若击退足以把目标推出
#   场地边缘，则击出地图。
#   value = 0：无伤害门槛，直接击出
#   value > 0：武器面板伤害必须严格超过目标当前生命的 value%
#   （面板伤害 = take_damage 的 value，暴击/护甲结算前）
#   运行时 key：fengliu_knockback_out_of_map
# ------------------------------------------------------------
# 效果值：
#   value  伤害阈值百分比（0 = 直接击出）
# ============================================================


static func get_id() -> String:
	return "fengliu_knockback_out_of_map"


# 槽位存 int 数组：[] = 没有效果，[0] = 有效果且直接击出
func fengliu_get_effect_init_value():
	return []


func apply(player_index: int) -> void :
	var effects = RunData.get_player_effects(player_index)
	var key := Keys.generate_hash(get_id())
	if not effects.has(key) or not (effects[key] is Array):
		effects[key] = []
	effects[key].push_back(value)


func unapply(player_index: int) -> void :
	var effects = RunData.get_player_effects(player_index)
	var key := Keys.generate_hash(get_id())
	if effects.has(key) and effects[key] is Array:
		effects[key].erase(value)


func get_args(_player_index: int) -> Array:
	# 描述文本占位符：[0] = 伤害阈值百分比（0 时表示直接击出）
	return [str(value)]
