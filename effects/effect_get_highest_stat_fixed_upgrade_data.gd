class_name GetHighestStatFixedUpgradeData
extends Effect


# ============================================================
# 效果：定向训练必含最高属性升级项
#   使「固定升级项」效果必包含当前最高主要属性的升级项。
#   运行时 custom_key：fengliu_get_highest_stat_fixed_upgrade_data
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================

# 获取最高属性对应的 UpgradeData
func get_highest_upgrade_data(player_index: int) -> int:
	var stat_hash = RunData.fengliu_get_highest_stat_hash(player_index)
	return ItemService.fengliu_get_upgrade_data_id_hash_by_stat(RunData.get_player_level(player_index), player_index, stat_hash)


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back(self)
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase(self)
