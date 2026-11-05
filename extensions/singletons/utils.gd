extends "res://singletons/utils.gd"


# 本 mod 的属性由物品套组注册
func reset_stat_keys() -> void:
	.reset_stat_keys()

	if ItemService.update_data_list == null:
		return

	for update_data in ItemService.update_data_list:
		if update_data == null or update_data.item_set == null:
			continue

		for set_stat in update_data.item_set.stats:
			if set_stat != null and not _stat_keys.has(set_stat.stat_hash):
				_stat_keys[set_stat.stat_hash] = 0
