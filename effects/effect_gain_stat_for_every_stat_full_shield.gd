class_name GainStatForEveryStatFullShield
extends "res://effects/items/gain_stat_for_every_stat_effect.gd"


# ============================================================
# 效果：满护盾时按倍率属性加属性
#   护盾满时，每有「value」点「stat_scaled」属性，加「nb_stat_scaled」点「key」属性；
#   护盾不满时不结算。护盾状态与道具增删由扩展脚本增删实际属性联动。
#   运行时 custom_key：fengliu_full_shield_stat_link
# ------------------------------------------------------------
# 效果值：
#   key              被加上的属性
#   value            每多少点倍率属性
#   nb_stat_scaled   每次加多少点
#   stat_scaled      倍率属性
#   perm_stats_only  只统计永久属性
#   need_full_shield 仅在护盾满时生效
# ============================================================

export (bool) var need_full_shield = true


static func get_id() -> String:
	return "fengliu_gain_stat_for_every_stat_full_shield"


func apply(player_index: int) -> void:
	# 先登记配置：护盾满/不满切换与道具增删由扩展脚本同步实际联动
	RunData.get_player_effect(custom_key_hash, player_index).push_back(self)

	# 不要求满盾时直接复用原版联动，行为与原版效果一致
	if not need_full_shield:
		.apply(player_index)


func unapply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).erase(self)

	if not need_full_shield:
		.unapply(player_index)


func serialize() -> Dictionary:
	var serialized = .serialize()
	serialized.need_full_shield = need_full_shield
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	need_full_shield = serialized.need_full_shield if "need_full_shield" in serialized else true
