extends "res://singletons/utils.gd"


# 覆盖: 1.2.0 的 _stat_keys 来自 PlayerRunData.init_stats() 的硬编码表；
# 本 mod 的属性按物品套组注册，只在套组启用时补进 _stat_keys（不做扁平 stats 兜底）
func reset_stat_keys() -> void:
	.reset_stat_keys()

	for update_data in ItemService.update_data_list:
		if update_data == null or update_data.item_set == null:
			continue
		if not ProgressData.has_item_set(update_data.id):
			continue
		for set_stat in update_data.item_set.stats:
			if set_stat != null and not _stat_keys.has(set_stat.stat_hash):
				_stat_keys[set_stat.stat_hash] = 0
