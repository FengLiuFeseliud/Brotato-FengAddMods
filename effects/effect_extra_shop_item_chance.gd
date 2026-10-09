class_name ExtraShopItemChance
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：额外商店道具概率
#   每持有 1 件带本效果的道具，商店就有概率额外出现 1 件该道具。
#   运行时 custom_key：fengliu_extra_shop_item_chance
# ------------------------------------------------------------
# 效果值：
#   key    目标道具 id，用于取道具名与写入商店
#   value  每持有 1 件的出现概率（百分比，例如 10 = 10%）
# ============================================================


static func get_id() -> String:
	return "fengliu_extra_shop_item_chance"


# 汇总该道具当前累计的出现概率（供描述 {2} 显示）
func get_all_chance(player_index: int) -> int:
	var chance = 0
	var effects = RunData.get_player_effect(custom_key_hash, player_index)
	for effect in effects:
		if key_hash != effect[0]:
			continue

		chance += effect[1]

	return chance


func apply(player_index: int) -> void:
	var effects = RunData.get_player_effect(custom_key_hash, player_index)
	for index in effects.size():
		if key_hash != effects[index][0]:
			continue

		effects[index] = [key_hash, effects[index][1] + value]
		return

	RunData.get_player_effects(player_index)[custom_key_hash].push_back([key_hash, value])


func unapply(player_index: int) -> void:
	var effects = RunData.get_player_effect(custom_key_hash, player_index)
	for index in effects.size():
		if key_hash != effects[index][0]:
			continue

		effects[index] = [key_hash, effects[index][1] - value]
		return

	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])


func get_args(player_index: int) -> Array:
	var item = ItemService.get_item_from_id(key_hash)
	var item_name = item.get_name_text() if item != null else tr(key.to_upper())

	return [
		item_name,
		"[color=lime]%s[/color]" % value,
		str(get_all_chance(player_index)),
	]
