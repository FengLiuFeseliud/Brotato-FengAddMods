extends "res://singletons/item_service.gd"


var effect_fengliu_can_all_drop_box = Keys.generate_hash("fengliu_can_all_drop_box")
var effect_fengliu_guaranteed_shop_items = Keys.generate_hash("fengliu_guaranteed_shop_items")
var effect_fengliu_get_fixed_upgrade = Keys.generate_hash("fengliu_get_fixed_upgrade")
var effect_fengliu_up_upgrade_data_tier = Keys.generate_hash("fengliu_up_upgrade_data_tier")
var effect_fengliu_swap_enemie = Keys.generate_hash("fengliu_swap_enemie")


var need_reroll_effect = [
	effect_fengliu_swap_enemie,
	effect_fengliu_get_fixed_upgrade
]


var _all_upgrade_ids = {}


# 计算动态概率
static func fengliu_get_dynamic_chance(init_chance: int, add_chance: int = 0, stat_count: int = 0) -> float:
	# 基础概率 + 属性数 * 每点加成
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	# 上限 100
	if dynamic_chance > 100:
		return 100.0 / 100
		
	return dynamic_chance / 100


# 扩展掉落传说箱子
func get_consumable_to_drop(unit: Unit, item_chance: float) -> ConsumableData:
    var consumable = .get_consumable_to_drop(unit, item_chance)
    if consumable == null:
        return consumable

    # 原本就是箱子则直接返回
    if consumable.my_id_hash == Keys.consumable_item_box_hash or consumable.my_id_hash == Keys.consumable_legendary_item_box_hash:
        return consumable
    
    var effect = null
    var player_index = 0
    # 查找持有掉箱效果的玩家
    for _player_index in RunData.get_player_count():
        var effects = RunData.get_player_effect(effect_fengliu_can_all_drop_box, _player_index)
        if effects.size() == 0:
            continue
            
        player_index = _player_index
        effect = effects[0]
        break

    if effect == null:
        return consumable

    var tier = Tier.UNCOMMON
    var stat_count = 0
    if effect[1] != 0:
        stat_count = RunData.get_stat(effect[0], player_index)

    # 概率升级为传说箱子
    if Utils.get_chance_success(fengliu_get_dynamic_chance(effect[2], effect[1], stat_count)):
        tier = Tier.LEGENDARY
    
    return get_consumable_for_tier(tier)


# 扩展保证商店道具
func get_player_shop_items(wave: int, player_index: int, args: ItemServiceGetShopItemsArgs) -> Array:
    var custom_guaranteed = RunData.get_player_effect(effect_fengliu_guaranteed_shop_items, player_index)

    # 无自定义保证道具则走原逻辑
    if custom_guaranteed.size() == 0:
        return .get_player_shop_items(wave, player_index, args)

    # 复用原版上限机制：统计已拥有（含锁定）且带 max_nb 限制的道具
    var limited_items = get_limited_items(args.owned_and_shop_items)

    # 临时把自定义保证道具合并进基础 guaranteed_shop_items
    # 每个 entry 为 [key_hash, value]
    var base_guaranteed = RunData.get_player_effect(Keys.guaranteed_shop_items_hash, player_index)
    var appended = 0
    for entry in custom_guaranteed:
        var item_hash = entry[0]

        # 已拥有达到 max_nb 上限（原版逻辑），不再固定出售
        if limited_items.has(item_hash) and limited_items[item_hash][1] >= limited_items[item_hash][0].max_nb:
            continue

        base_guaranteed.append([item_hash, 1])
        appended += 1

    # 基础逻辑会自动替换随机商品并安全截断到商店上限
    var result = .get_player_shop_items(wave, player_index, args)

    # 还原，避免污染基础效果数据
    for i in appended:
        base_guaranteed.pop_back()

    return result


# 判断效果是否需要重新随机预报
func _fengliu_effect_needs_reroll(effect) -> bool:
    if effect.custom_key_hash == Keys.empty_hash and effect.custom_key != "":
        effect.custom_key_hash = Keys.generate_hash(effect.custom_key)
    return effect.custom_key_hash in need_reroll_effect


# 覆写随机道具生成：让箱子开出的预报道具重随预报
func _get_rand_item_for_wave(wave: int, player_index: int, type: int, args: GetRandItemForWaveArgs) -> ItemParentData:
    var item = ._get_rand_item_for_wave(wave, player_index, type, args)
    if item == null or item.effects == null:
        return item

    # 先扫描是否存在需要重新随机预报的效果
    var has_reroll_effect = false
    for effect in item.effects:
        if _fengliu_effect_needs_reroll(effect):
            has_reroll_effect = true
            break

    if not has_reroll_effect:
        return item

    # 复制 item，并逐个复制需要重随的效果，避免污染商店池里的模板资源
    var new_item = item.duplicate()
    var new_effects = []
    for effect in new_item.effects:
        if _fengliu_effect_needs_reroll(effect):
            effect = effect.duplicate()
            effect.fengliu_roll_effect(player_index)
        new_effects.append(effect)

    new_item.effects = new_effects
    return new_item


# 获取所有升级项 id 哈希
func fengliu_get_all_upgrade_id_hashs() -> Array:
    if _all_upgrade_ids.size() != 0:
        return _all_upgrade_ids.values()

    for tier in range(_tiers_data.size()):
        for upgrade in _tiers_data[tier][TierData.UPGRADES]:
            _all_upgrade_ids[upgrade.upgrade_id] = upgrade.upgrade_id_hash
    return _all_upgrade_ids.values()


# 获取指定品阶与 id 的升级数据
func fengliu_get_upgrade_data(tier: int, player_index: int, upgrade_id_hash: int) -> UpgradeData:
    var upgrade_data = null
    var pool: Array = _tiers_data[tier][TierData.UPGRADES]
    for upgrade in pool:
        if upgrade.upgrade_id_hash != upgrade_id_hash:
            continue
        return upgrade

    if upgrade_data == null:
        upgrade_data = Utils.get_rand_element(pool)
    
    var level_upgrades_modifications = RunData.get_player_effect(Keys.level_upgrades_modifications_hash, player_index)
    if level_upgrades_modifications == 0:
        return upgrade_data

    var new_effects = []
    upgrade_data = upgrade_data.duplicate()
    for effect in upgrade_data.effects:
        var new_effect = effect.duplicate()
        new_effect.value = int(effect.value * (1.0 + level_upgrades_modifications / 100.0))
        new_effects.push_back(new_effect)

    upgrade_data.effects = new_effects
    return upgrade_data


# 获取固定升级数据（按等级定品阶）
func fengliu_get_fixed_upgrade_data(level: int, player_index: int, upgrade_id_hash: int) -> UpgradeData:
    var tier = get_tier_from_wave(level, player_index)

    # 原版的特殊等级规则
    if level == 5:
        tier = Tier.UNCOMMON
    elif level == 10 or level == 15 or level == 20:
        tier = Tier.RARE
    elif level % 5 == 0:
        tier = Tier.LEGENDARY

    return fengliu_get_upgrade_data(tier, player_index, upgrade_id_hash)


# 按属性获取升级项 id 哈希
func fengliu_get_upgrade_data_id_hash_by_stat(level: int, player_index: int, stat_hash: int) -> int:
    var pool: Array = _tiers_data[0][TierData.UPGRADES]
    for upgrade in pool:
        for effect in upgrade.effects:
            if effect.key_hash == stat_hash:
                return upgrade.upgrade_id_hash

    return Utils.get_rand_element(pool).upgrade_id_hash


# 获取固定升级项数组
func fengliu_get_fixed_upgrade(level: int, effect, player_index: int) -> Array:
    var all_fixed_upgrade = []
    for upgrade_id_hash in effect.all_fixed_upgrade_id_hashs:
        all_fixed_upgrade.append(fengliu_get_fixed_upgrade_data(level, player_index, upgrade_id_hash))

    return all_fixed_upgrade


# 提升升级项品阶
func fengliu_up_upgrade_data_tier(effect: Array, upgrades: Array, player_index: int) -> Array:
    var gain_value = 0
    if effect[0] != Keys.empty_hash:
        var stat_value = 0
        if effect[0] == Keys.stat_levels_hash:
            stat_value = RunData.get_player_level(player_index)
        else:
            stat_value = RunData.get_stat(effect[0], player_index)
        gain_value = stat_value * (effect[2] / 100.0) / 100.0
        
    var chance = effect[1] / 100.0 + gain_value
    if not Utils.get_chance_success(chance):
        return upgrades

    var new_upgrades = []
    for upgrade in upgrades:
        if upgrade.tier >= 3:
            continue
        
        new_upgrades.append(fengliu_get_upgrade_data(upgrade.tier + 1, player_index, upgrade.upgrade_id_hash))

    return new_upgrades


# 扩展生成升级项
func get_upgrades(level: int, number: int, old_upgrades: Array, player_index: int) -> Array:
    var upgrades = []
    var effects = RunData.get_player_effect(effect_fengliu_get_fixed_upgrade, player_index)
    if effects.size() > 0:
        upgrades = fengliu_get_fixed_upgrade(level, effects[0], player_index)
    else:
        upgrades =.get_upgrades(level, number, old_upgrades, player_index)

    for effect in RunData.get_player_effect(effect_fengliu_up_upgrade_data_tier, player_index):
        upgrades = fengliu_up_upgrade_data_tier(effect, upgrades, player_index)

    return upgrades
