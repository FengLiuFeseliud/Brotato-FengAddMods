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


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back([value])


func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([value])


func get_args(player_index: int) -> Array:
	# 描述文本占位符：
	#   [0] = 触发概率百分比（基类 args[0]，绿色；% 由 text.gd 的 percent 表补）
	var args = .get_args(player_index)
	return [
		str(args[0])
	]
