extends "res://mods-unpacked/FengLiu-FengAddMods/effects/effect_below_hp_full_restore.gd"


# ============================================================
# 效果：金苹果
#   低于阈值时：
#     1) 获得所有「生存向」品阶 I（1 级 / 白）升级项的属性
#     2) 刷新属性，让新上限立即生效
#     3) 回满生命与护盾
#     4) 消耗触发本效果的金苹果（无 replaced_by，直接消失）
#   生存向口径复用 ItemService 现有 fengliu_icon_hp_upgrade 池：
#     最大生命 / 生命再生 / 吸血 / 护甲 / 闪避 /
#     收获 / 移速 / 护盾 / 幸运
#   阈值 / 每波一次 / 文案由 .tres 配置。
# ============================================================

# 品阶 I = 0（普通 / 白）
const GRANT_UPGRADE_TIER := 0
const GRANT_UPGRADE_ROMAN := "I"


static func get_id() -> String:
	return "fengliu_golden_apple"


# 每个玩家只保留一个金苹果效果实例


func apply(player_index: int) -> void:
	var slot_hash: int = Keys.generate_hash("fengliu_below_hp")
	var slot = RunData.get_player_effects(player_index).get(slot_hash, [])
	if slot is Array:
		for effect in slot:
			if effect != null and effect.get_id() == get_id():
				return

	.apply(player_index)


func unapply(player_index: int) -> void:
	# 只要背包里还有金苹果，就保留唯一效果，供后续低血量事件使用
	if _fengliu_count_golden_apples(player_index) > 0:
		return

	var slot_hash: int = Keys.generate_hash("fengliu_below_hp")
	var slot = RunData.get_player_effects(player_index).get(slot_hash, [])
	if not (slot is Array):
		return

	# 清掉所有金苹果效果（槽实例可能与当前 unapply 的 self 不是同一个）
	for i in range(slot.size() - 1, -1, -1):
		var effect = slot[i]
		if effect != null and effect.get_id() == get_id():
			slot.remove(i)


func _fengliu_count_golden_apples(player_index: int) -> int:
	var count := 0
	var item_id: String = owner_item_id if owner_item_id != "" else "item_golden_apple"
	for item in RunData.get_player_items_ref(player_index):
		if item != null and item.my_id == item_id:
			count += 1
	return count


func fengliu_below_hp_execute(player_index: int) -> void:
	var player = _fengliu_get_player(player_index)
	if player == null:
		return

	_fengliu_grant_survival_white_upgrades(player_index)

	# 让升级带来的最大生命 / 护盾上限立即生效
	if player.has_method("update_player_stats"):
		player.update_player_stats()

	# 父类回满生命与护盾，并消耗金苹果
	.fengliu_below_hp_execute(player_index)


# 只发放 Tier I 中属于现有生存池的升级项
func _fengliu_grant_survival_white_upgrades(player_index: int) -> void:
	var survival_stats: Array = ItemService.fengliu_upgrades_pools.get(ItemService.fengliu_hp_upgrade_hash, [])
	if survival_stats.empty():
		return

	var allowed_stats := {}
	for stat_hash in survival_stats:
		allowed_stats[stat_hash] = true

	var applied := {}
	for upgrade in ItemService.fengliu_get_tier_upgrade_pool(GRANT_UPGRADE_TIER):
		if upgrade == null:
			continue

		# 早期调用时升级资源可能还没生成哈希，先补齐再匹配
		if upgrade.upgrade_id_hash == Keys.empty_hash and upgrade.upgrade_id != "":
			upgrade._generate_hashes()
		if upgrade.effects != null:
			for upgrade_effect in upgrade.effects:
				if upgrade_effect != null and upgrade_effect.key_hash == Keys.empty_hash and upgrade_effect.key != "":
					upgrade_effect._generate_hashes()

		if applied.has(upgrade.upgrade_id_hash):
			continue

		var is_survival := false
		for effect in upgrade.effects:
			if effect != null and allowed_stats.has(effect.key_hash):
				is_survival = true
				break

		if not is_survival:
			continue

		applied[upgrade.upgrade_id_hash] = true
		var upgrade_data = upgrade.duplicate()
		upgrade_data = RunData.fengliu_apply_reset_stats_to_item(upgrade_data, player_index)
		RunData.apply_item_effects(upgrade_data, player_index)


func get_args(_player_index: int) -> Array:
	# {0} = 阈值（text.gd 补绿与 %）
	# {1} = 品阶罗马数字
	return [str(hp_threshold_pct), GRANT_UPGRADE_ROMAN]


func get_args_tool() -> Array:
	return [str(hp_threshold_pct), GRANT_UPGRADE_ROMAN]
