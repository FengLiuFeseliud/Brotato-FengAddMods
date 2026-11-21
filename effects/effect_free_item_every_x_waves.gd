class_name FreeItemEveryXWaves
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：每 x 波免费获得一个指定道具
#   每 x 波开始时（第 x、2x、3x… 波），免费获得 1 个指定的道具
#   （直接进背包，不消耗材料、不看商店）。
#   运行时 custom_key：fengliu_free_item_every_x_waves
# ------------------------------------------------------------
# 效果值：
#   value      间隔波数（x）
#   item_data  指定道具（ItemData 资源）
# ============================================================

export (Resource) var item_data


static func get_id() -> String:
	return "fengliu_free_item_every_x_waves"


# 数值累加 / 消费端遍历，异变复制有效
func fengliu_can_be_copied_by_mutation() -> bool:
	return true


func fengliu_get_item_id_hash() -> int:
	if item_data != null and item_data is ItemData:
		return item_data.my_id_hash
	return Keys.empty_hash


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back([value, fengliu_get_item_id_hash()])


func unapply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).erase([value, fengliu_get_item_id_hash()])


func fengliu_get_effect_init_value():
	return []


func get_args(_player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{1} 占位符：
	#   [0] = 间隔波数
	#   [1] = 指定道具名
	var item_name := ""
	if item_data != null and item_data is ItemData:
		item_name = tr(item_data.name)
	return [str(value), item_name]
