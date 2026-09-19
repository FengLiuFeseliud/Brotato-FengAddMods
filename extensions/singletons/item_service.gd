extends "res://singletons/item_service.gd"


const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_EFFECTS_DIR = "res://mods-unpacked/FengLiu-FengAddMods/effects/"


var effect_fengliu_can_all_drop_box = Keys.generate_hash("fengliu_can_all_drop_box")
var effect_fengliu_guaranteed_shop_items = Keys.generate_hash("fengliu_guaranteed_shop_items")
var effect_fengliu_get_fixed_upgrade = Keys.generate_hash("fengliu_get_fixed_upgrade")
var effect_fengliu_up_upgrade_data_tier = Keys.generate_hash("fengliu_up_upgrade_data_tier")
var effect_fengliu_swap_enemie = Keys.generate_hash("fengliu_swap_enemie")
var effect_fengliu_can_rand_set_weapon = Keys.generate_hash("fengliu_can_rand_set_weapon")


# 需要重新随机的效果列表
var need_reroll_effect = [
	effect_fengliu_swap_enemie,
	effect_fengliu_get_fixed_upgrade,
    effect_fengliu_can_rand_set_weapon
]


# 全部升级项 id 哈希缓存
var _all_upgrade_ids = {}


func _enter_tree() -> void:
	_fengliu_register_effect_prototypes()


# 注册本 mod 全部效果脚本为存档还原原型（必须早于 ContentLoader 触发的那次读档）
# 幂等：ResourceLoader 有缓存，同一路径拿到同一对象，has() 去重即可
func _fengliu_register_effect_prototypes() -> void:
	var registered := 0
	var skipped := 0

	# 逐个加载效果脚本，只有自带唯一 id 的具体效果才能被读档匹配
	for effect_path in _fengliu_collect_effect_script_paths(FENGLIU_EFFECTS_DIR):
		var effect_script = load(effect_path)
		if effect_script == null or not (effect_script is GDScript):
			skipped += 1
			ModLoaderLog.warning("Failed to load effect script: %s" % effect_path, FENGLIU_MOD_ID)
			continue

		if not _fengliu_is_registerable_effect(effect_script):
			skipped += 1
			continue

		if effects.has(effect_script):
			continue

		effects.push_back(effect_script)
		registered += 1

	ModLoaderLog.info("Registered %d effect prototypes from %s (skipped %d)." % [registered, FENGLIU_EFFECTS_DIR, skipped], FENGLIU_MOD_ID)


# 是否登记为原型：是效果类，且自带唯一 id（基类与仍继承 id 的脚本一律跳过）
func _fengliu_is_registerable_effect(effect_script) -> bool:
	# 实例化后确认是效果类（基类也会通过，靠 id 判定再剔除）
	var effect_instance = effect_script.new()
	if not (effect_instance is Effect):
		return false

	# 取基类脚本，与自身 id 不同即视为自带唯一 id
	var base_script = effect_script.get_base_script()
	if base_script == null:
		return false

	return effect_script.get_id() != base_script.get_id()


# 递归收集效果脚本路径（排序，保证注册顺序稳定可复现）
func _fengliu_collect_effect_script_paths(dir_path: String) -> Array:
	var script_paths := []

	# 打不开目录时记错误并返回空列表
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		ModLoaderLog.error("Failed to open effects directory: %s" % dir_path, FENGLIU_MOD_ID)
		return script_paths

	# 递归子目录并排序，保证注册顺序稳定可复现
	dir.list_dir_begin(true, true)
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.plus_file(file_name)
		if dir.current_is_dir():
			script_paths.append_array(_fengliu_collect_effect_script_paths(full_path))
		elif file_name.get_extension() == "gd":
			script_paths.push_back(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	script_paths.sort()
	return script_paths


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

    # 基础逻辑会自动替换随机道具并安全截断到商店上限
    var result = .get_player_shop_items(wave, player_index, args)

    # 还原，避免污染基础效果数据
    for i in appended:
        base_guaranteed.pop_back()

    return result


# 判断效果是否需要重新随机预报
func _fengliu_effect_needs_reroll(effect) -> bool:
    # 未生成哈希时按 custom_key 补算
    if effect.custom_key_hash == Keys.empty_hash and effect.custom_key != "":
        effect.custom_key_hash = Keys.generate_hash(effect.custom_key)
    # 是否属于需要重随的效果
    return effect.custom_key_hash in need_reroll_effect


# 判断是否重复武器（同家族低品阶 / 已满阶不可升级视为重复）
func fengliu_is_duplicate_weapon(weapon, unique_weapon_ids: Dictionary) -> bool:
    # 同家族低品阶、或已满阶不可升级的同名武器视为重复
    for owned_weapon in unique_weapon_ids.values():
        if weapon.weapon_id_hash == owned_weapon.weapon_id_hash and weapon.tier < owned_weapon.tier:
            return true
        if weapon.my_id_hash == owned_weapon.my_id_hash and owned_weapon.upgrades_into == null:
            return true

    return false


# 收集目标套装武器候选（排除本波已出现、禁用品、数量超限与类型禁用）
func fengliu_get_set_weapon_candidates(set_hash: int, player_index: int, item_tier: int, args: GetRandItemForWaveArgs) -> Array:
    # 本波商店已出现/已锁定的物品，避免同波重复
    var excluded_ids = []
    for shop_item in args.excluded_items:
        excluded_ids.append(shop_item[0].my_id_hash)

    var banned_items = RunData.players_data[player_index].banned_items
    var player_character = RunData.get_player_character(player_index)
    var limited_items = get_limited_items(args.owned_and_shop_items)

    var no_melee_weapons: bool = RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, player_index)
    var no_ranged_weapons: bool = RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, player_index)
    var no_duplicate_weapons: bool = RunData.get_player_effect_bool(Keys.no_duplicate_weapons_hash, player_index)
    var no_structures: bool = RunData.get_player_effect(Keys.remove_shop_items_hash, player_index).has(Keys.structure_hash)
    var unique_weapon_ids: Dictionary = RunData.get_unique_weapon_ids(player_index)

    var candidates = []
    for weapon in get_pool(item_tier, TierData.WEAPONS):
        # 必须是目标套装
        if not fengliu_weapon_in_set_hashs(weapon, set_hash):
            continue

        # 本波已出现
        if excluded_ids.has(weapon.my_id_hash):
            continue

        # 玩家禁用品（哈希或字符串 id）
        if banned_items.has(weapon.my_id_hash) or banned_items.has(weapon.my_id):
            continue

        # 角色禁用品
        if player_character.banned_items.has(weapon.my_id):
            continue

        # 数量上限
        if limited_items.has(weapon.my_id_hash) and limited_items[weapon.my_id_hash][1] >= weapon.max_nb:
            continue

        # 无近战 / 无远程 / 无构筑物
        if no_melee_weapons and weapon.type == WeaponType.MELEE:
            continue
        if no_ranged_weapons and weapon.type == WeaponType.RANGED:
            continue
        if no_structures and EntityService.is_weapon_spawning_structure(weapon):
            continue

        # 禁重复武器（与基类相同判定）
        if no_duplicate_weapons and fengliu_is_duplicate_weapon(weapon, unique_weapon_ids):
            continue

        candidates.append(weapon)

    return candidates


# 随机取一把目标套装武器（无有效套装或候选时返回 null）
func fengliu_get_rand_set_weapon(set_hash: int, wave: int, player_index: int, args: GetRandItemForWaveArgs) -> ItemParentData:
    # 无效套装直接返回，由调用方回退原版随机
    if set_hash == Keys.empty_hash:
        return null

    var item_tier = get_tier_from_wave(wave, player_index, args.increase_tier)
    if args.fixed_tier != -1:
        item_tier = args.fixed_tier

    var min_weapon_tier: int = RunData.get_player_effect(Keys.min_weapon_tier_hash, player_index)
    var max_weapon_tier: int = RunData.get_player_effect(Keys.max_weapon_tier_hash, player_index)
    item_tier = clamp(item_tier, min_weapon_tier, max_weapon_tier)

    var candidates = fengliu_get_set_weapon_candidates(set_hash, player_index, item_tier, args)
    if candidates.size() == 0:
        return null

    return apply_item_effect_modifications(Utils.get_rand_element(candidates), player_index)


# 判断武器是否属于目标套装
func fengliu_weapon_in_set_hashs(weapon, set_hash: int) -> bool:
    if set_hash == Keys.empty_hash or weapon.sets == null:
        return false

    # 任一所属套装匹配即为目标套装
    for set_item in weapon.sets:
        if set_item != null and set_item.my_id_hash == set_hash:
            return true

    return false


# 商店刷新后处理：把非目标套装的武器替换为目标套装武器（取不到则保留原物）
func fengliu_roll_set_weapon_in_shop(shop_items: Array, locked_count: int, wave: int, player_index: int, owned_and_shop_items: Array, increase_tier: int = 0) -> int:
    var replaced = 0
    var effects = RunData.get_player_effect(effect_fengliu_can_rand_set_weapon, player_index)
    if effects.size() <= 0:
        return replaced

    var set_hash = effects[0][0]
    for index in range(shop_items.size()):
        # 玩家手动锁定的道具保持原样
        if index < locked_count:
            continue

        var shop_entry = shop_items[index]
        if not (shop_entry is Array) or shop_entry.size() == 0:
            continue

        var item = shop_entry[0]
        # 只处理武器格，道具格保持原样
        if item == null or not (item is WeaponData):
            continue

        # 已是目标套装武器则不处理
        if fengliu_weapon_in_set_hashs(item, set_hash):
            continue

        var args = GetRandItemForWaveArgs.new()
        args.excluded_items = shop_items
        args.owned_and_shop_items = owned_and_shop_items
        args.increase_tier = increase_tier

        var new_weapon = fengliu_get_rand_set_weapon(set_hash, wave, player_index, args)
        # 无候选则保留原道具，避免出现空格子
        if new_weapon == null:
            continue

        shop_entry[0] = new_weapon
        replaced += 1

    return replaced


# 扩展随机道具：命中需要重随预报的效果时返回副本
func _get_rand_item_for_wave(wave: int, player_index: int, type: int, args: GetRandItemForWaveArgs) -> ItemParentData:
    var item = ._get_rand_item_for_wave(wave, player_index, type, args)
    if item == null:
        return item

    if item.effects == null:
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
    # 已缓存则直接返回
    if _all_upgrade_ids.size() != 0:
        return _all_upgrade_ids.values()

    # 遍历所有品阶收集升级项
    for tier in range(_tiers_data.size()):
        for upgrade in _tiers_data[tier][TierData.UPGRADES]:
            # 缓存升级项 id 与哈希
            _all_upgrade_ids[upgrade.upgrade_id] = upgrade.upgrade_id_hash
    return _all_upgrade_ids.values()


# 获取指定品阶与 id 的升级数据
func fengliu_get_upgrade_data(tier: int, player_index: int, upgrade_id_hash: int) -> UpgradeData:
    var upgrade_data = null
    # 在对应品阶池中查找指定升级项
    var pool: Array = _tiers_data[tier][TierData.UPGRADES]
    for upgrade in pool:
        if upgrade.upgrade_id_hash != upgrade_id_hash:
            continue
        upgrade_data = upgrade
        break

    # 未找到则随机取一个
    if upgrade_data == null:
        upgrade_data = Utils.get_rand_element(pool)
    
    # 读取升级效果倍率
    var level_upgrades_modifications = RunData.get_player_effect(Keys.level_upgrades_modifications_hash, player_index)
    # 无倍率则直接返回
    if level_upgrades_modifications == 0:
        return upgrade_data

    var new_effects = []
    # 复制升级项并按倍率放大效果值
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
func fengliu_get_upgrade_data_id_hash_by_stat(stat_hash: int) -> int:
    # 查找含指定属性的升级项
    var pool: Array = _tiers_data[0][TierData.UPGRADES]
    for upgrade in pool:
        for effect in upgrade.effects:
            if effect.key_hash == stat_hash:
                return upgrade.upgrade_id_hash

    # 未找到则随机返回一个
    return Utils.get_rand_element(pool).upgrade_id_hash


# 获取固定升级项数组
func fengliu_get_fixed_upgrade(level: int, effect, player_index: int) -> Array:
    var all_fixed_upgrade = []
    # 逐个取出固定升级项的数据
    for upgrade_id_hash in effect.all_fixed_upgrade_id_hashs:
        all_fixed_upgrade.append(fengliu_get_fixed_upgrade_data(level, player_index, upgrade_id_hash))

    return all_fixed_upgrade


# 提升升级项品阶
func fengliu_up_upgrade_data_tier(effect: Array, upgrades: Array, player_index: int) -> Array:
    var gain_value = 0
    # 有倍率属性则按属性计算额外概率
    if effect[0] != Keys.empty_hash:
        var stat_value = 0
        if effect[0] == Keys.stat_levels_hash:
            stat_value = RunData.get_player_level(player_index)
        else:
            stat_value = RunData.get_stat(effect[0], player_index)
        gain_value = stat_value * (effect[3] / 100.0) / 100.0
        
    # 概率未命中则保持原升级项
    var chance = effect[2] / 100.0 + gain_value
    if not Utils.get_chance_success(chance):
        return upgrades

    # 逐个提升升级项品阶
    var new_upgrades = []
    for upgrade in upgrades:
        # 已达最高品阶不再升阶
        if upgrade.tier >= 3:
            new_upgrades.append(upgrade)
            continue

        # 提升 effect[1] 个品阶并封顶最高品阶
        var new_tier = upgrade.tier + effect[1]
        if new_tier > 3:
            new_tier = 3

        new_upgrades.append(fengliu_get_upgrade_data(new_tier, player_index, upgrade.upgrade_id_hash))

    return new_upgrades


# 扩展生成升级项
func get_upgrades(level: int, number: int, old_upgrades: Array, player_index: int) -> Array:
    var upgrades = .get_upgrades(level, number, old_upgrades, player_index)
    # 有固定升级项效果则替换升级项
    var effects = RunData.get_player_effect(effect_fengliu_get_fixed_upgrade, player_index)
    if effects.size() > 0 and effects[0].all_fixed_upgrade_id_hashs.size() >= 4:
        upgrades = fengliu_get_fixed_upgrade(level, effects[0], player_index)

    # 应用升级项品阶提升效果
    for effect in RunData.get_player_effect(effect_fengliu_up_upgrade_data_tier, player_index):
        upgrades = fengliu_up_upgrade_data_tier(effect, upgrades, player_index)

    return upgrades


# 扩展道具效果修正：商店/掉落随机生成"被诅咒"的道具或武器后，
# 若为水壶则立即还原其收获产树效果，避免被诅咒改成"另一个效果"并放大 value
func apply_item_effect_modifications(item: ItemParentData, player_index: int) -> ItemParentData:
    # 先走原版的道具效果修正
    var new_item = .apply_item_effect_modifications(item, player_index)
    RunData.fengliu_normalize_cursed_effect(new_item)
    return new_item

