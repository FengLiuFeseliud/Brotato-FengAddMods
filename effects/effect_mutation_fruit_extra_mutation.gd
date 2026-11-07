class_name MutationFruitExtraMutation
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：拾取变异果（mutant_consumable_fruit）时有概率额外获得一次变异
#   目标果子硬编码在 extensions/entities/units/player/player.gd；
#   本效果用 apply/unapply 写入/移除数组槽位 [value]（不存 self）。
#   变异次数在本波结束时由 RunData.on_wave_end() → mutate_random_item() 结算。
#   运行时 custom_key：fengliu_mutation_fruit_extra_mutation
# ------------------------------------------------------------
# 效果值：
#   value  触发概率（%）
# ============================================================


static func get_id() -> String:
	return "fengliu_mutation_fruit_extra_mutation"


# 数值累加 / 消费端遍历，异变复制有效
func fengliu_can_be_copied_by_mutation() -> bool:
	return true


func apply(player_index: int) -> void :
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = effects.get(custom_key_hash, 0) + value


func unapply(player_index: int) -> void :
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = max(0, effects.get(custom_key_hash, 0) - value)


# 槽位存的是单个数值（不是列表）
func fengliu_get_effect_init_value():
	return 0


func get_args(player_index: int) -> Array:
	# 描述文本占位符：
	#   [0] = 触发概率百分比（基类 args[0]，绿色；% 由 text.gd 的 percent 表补）
	var args = .get_args(player_index)
	return [
		str(args[0])
	]