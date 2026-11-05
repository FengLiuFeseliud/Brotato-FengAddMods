extends "res://singletons/item_service.gd"


const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_EFFECTS_DIR = "res://mods-unpacked/FengLiu-FengAddMods/effects/"
const FENGLIU_STATS_DIR = "res://mods-unpacked/FengLiu-FengAddMods/content_data/stats/"
const FENGLIU_MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"

const FENGLIU_EXTRA_EFFECT_PROTOTYPES := [
	"res://mods-unpacked/FengLiu-FengAddMods/content_data/characters/creeper/creeper_exploding_effect.gd"
]

# 1.2.0 物品套组
const FENGLIU_ITEM_SET_ID = "fengliu_set"
const FENGLIU_UPDATE_TRES = "res://mods-unpacked/FengLiu-FengAddMods/content_data/item_set/fengliu_update.tres"
const FENGLIU_CONTENT_DIR = "res://mods-unpacked/FengLiu-FengAddMods/content_data/"
# 参与原生注册的子目录（其余目录只放子资源，不注册）
const FENGLIU_DYNAMIC_CONTENT_SUBDIRS := ["characters", "items", "weapons", "sets", "upgrades"]


# 图鉴 / 道具套组只显示 previous_upgrade == null 的武器；
# 这里只补「展示用前阶指针」，不写 upgrades_into ⇒ 商店升级 / 合成玩法不变
const FENGLIU_CODEX_HIDDEN_WEAPON_CHAIN := {
	"wood_pickaxe": "stone_pickaxe",
	"stone_pickaxe": "iron_pickaxe",
	"iron_pickaxe": "diamond_pickaxe"
}


const FENGLIU_UPGRADE_POOL_STATS := {
	"fengliu_icon_damage_upgrade": [
		"stat_melee_damage", "stat_ranged_damage", "stat_percent_damage", "stat_engineering", "stat_range", "stat_attack_speed", "stat_crit_chance", "stat_elemental_damage",
	],
	"fengliu_icon_hp_upgrade": [
		"stat_max_hp", "stat_hp_regeneration", "stat_lifesteal", "stat_armor", "stat_dodge", "stat_harvesting", "stat_speed", "stat_fengliu_shield", "stat_luck"
	]
}


var effect_fengliu_can_all_drop_box = Keys.generate_hash("fengliu_can_all_drop_box")
var effect_fengliu_guaranteed_shop_items = Keys.generate_hash("fengliu_guaranteed_shop_items")
var effect_fengliu_get_fixed_upgrade = Keys.generate_hash("fengliu_get_fixed_upgrade")
var effect_fengliu_up_upgrade_data_tier = Keys.generate_hash("fengliu_up_upgrade_data_tier")
var effect_fengliu_swap_enemie = Keys.generate_hash("fengliu_swap_enemie")
var effect_fengliu_can_rand_set_weapon = Keys.generate_hash("fengliu_can_rand_set_weapon")
var effect_fengliu_extra_wanted_item_tag = Keys.generate_hash("fengliu_extra_wanted_item_tag")
var effect_fengliu_extra_shop_item_chance = Keys.generate_hash("fengliu_extra_shop_item_chance")
var effect_fengliu_add_random_character_to_shop = Keys.generate_hash("fengliu_add_random_character_to_shop")
var effect_fengliu_reset_item_stat = Keys.generate_hash("fengliu_reset_item_stat")


var fengliu_wanted_item_tag_chance_hash = Keys.generate_hash("fengliu_wanted_item_tag_chance")

var fengliu_damage_upgrade_hash = Keys.generate_hash("fengliu_icon_damage_upgrade")
var fengliu_hp_upgrade_hash = Keys.generate_hash("fengliu_icon_hp_upgrade")


var fengliu_upgrades_pools = {}


# 需要重新随机的效果列表
var need_reroll_effect = [
	effect_fengliu_swap_enemie,
	effect_fengliu_get_fixed_upgrade,
    effect_fengliu_can_rand_set_weapon,
    effect_fengliu_extra_wanted_item_tag
]


# 全部升级项 id 哈希缓存
var _all_upgrade_ids = {}

# 原生内容是否已注册
var _fengliu_content_registered := false


func _ready():
    for key in FENGLIU_UPGRADE_POOL_STATS.keys():
        var pool = []
        for stat_id in FENGLIU_UPGRADE_POOL_STATS[key]:
            pool.append(Keys.generate_hash(stat_id))

        fengliu_upgrades_pools[Keys.generate_hash(key)] = pool

    # 1.2.0：原生注册全部内容（物品套组 + 武器套装 + 升级项）
    _fengliu_register_all_content()


func _enter_tree() -> void:
	_fengliu_register_effect_prototypes()
	_fengliu_register_stats()


# 注册本 mod 的自定义属性资源
func _fengliu_register_stats() -> void:
	var dir := Directory.new()
	# 打不开目录时直接放弃
	if dir.open(FENGLIU_STATS_DIR) != OK:
		return
        
	# 逐个登记目录下的 .tres 属性资源（同名属性只登记一次）
	dir.list_dir_begin(true, true)
	var file_name := dir.get_next()
	while file_name.length() > 0:
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			var stat_resource = load(FENGLIU_STATS_DIR.plus_file(file_name))
			if stat_resource is StatData and not _fengliu_has_custom_stat(stat_resource.stat_name):
				# 属性哈希默认是 call_deferred 生成，这里立即补算
				stat_resource.generate_hashes()
				stats.push_back(stat_resource)
		file_name = dir.get_next()
	dir.list_dir_end()


# 判断自定义属性是否已登记
func _fengliu_has_custom_stat(stat_name: String) -> bool:
	for existing_stat in stats:
		if existing_stat is StatData and existing_stat.stat_name == stat_name:
			return true
	return false


# 注册本 mod 全部效果脚本为存档还原原型（必须早于 ContentLoader 触发的那次读档）
# 幂等：ResourceLoader 有缓存，同一路径拿到同一对象，has() 去重即可
func _fengliu_register_effect_prototypes() -> void:
	var registered := 0
	var skipped := 0

	# 逐个加载效果脚本，只有自带唯一 id 的具体效果才能被读档匹配
	for effect_path in _fengliu_collect_effect_script_paths(FENGLIU_EFFECTS_DIR):
		if _fengliu_try_register_effect_prototype(effect_path) > 0:
			registered += 1
		else:
			skipped += 1

	# 目录外（content_data 下）的效果脚本显式登记
	for effect_path in FENGLIU_EXTRA_EFFECT_PROTOTYPES:
		if _fengliu_try_register_effect_prototype(effect_path) > 0:
			registered += 1
		else:
			skipped += 1

	ModLoaderLog.info("Registered %d effect prototypes from %s (skipped %d)." % [registered, FENGLIU_EFFECTS_DIR, skipped], FENGLIU_MOD_ID)


# 尝试登记单个效果脚本为读档原型：返回 1 表示本次登记成功
func _fengliu_try_register_effect_prototype(effect_path: String) -> int:
	var effect_script = load(effect_path)
	if effect_script == null or not (effect_script is GDScript):
		ModLoaderLog.warning("Failed to load effect script: %s" % effect_path, FENGLIU_MOD_ID)
		return 0

	if not _fengliu_is_registerable_effect(effect_script):
		return 0

	if effects.has(effect_script):
		return 0

	effects.push_back(effect_script)
	return 1


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


# 自定义保证商店道具
func fengliu_guaranteed_shop_items(effect: Array, wave: int, player_index: int, args: ItemServiceGetShopItemsArgs) -> Array:
    # 临时把自定义保证道具合并进基础 guaranteed_shop_items
    var base_guaranteed = RunData.get_player_effect(Keys.guaranteed_shop_items_hash, player_index)
    var appended = 0
    for entry in effect:
        var item_hash = entry[0]
        var item_data = fengliu_get_shop_extra_item(item_hash)
        if item_data == null:
            continue

        # 只看同名道具：replaced_by 的失效版（max_nb 常为 -1）不占原道具上限，
        # 否则「失效的定向训练」会让正版永远不再保底
        if item_data.max_nb != -1 and fengliu_count_same_items(item_hash, args.owned_and_shop_items) >= item_data.max_nb:
            continue

        base_guaranteed.append([item_hash, 1])
        appended += 1

    var result = .get_player_shop_items(wave, player_index, args)

    for i in appended:
        base_guaranteed.pop_back()

    return result


# 统计「同名」道具数量：不把 replaced_by 的失效版算进来
#（失效版 max_nb 常为 -1，用 origin 聚合会把原道具的 max_nb 永久占满）
func fengliu_count_same_items(item_hash: int, from_items: Array) -> int:
    var count := 0
    for item in from_items:
        if item != null and item.my_id_hash == item_hash:
            count += 1
    return count


# 目标道具是否已达 max_nb 上限（只看同名，失效版不占原道具上限）
func fengliu_shop_slot_reached_limit(item_hash: int, owned_and_shop_items: Array, result: Array) -> bool:
    var item = fengliu_get_shop_extra_item(item_hash)
    if item == null or item.max_nb == -1:
        return false

    var count = fengliu_count_same_items(item_hash, owned_and_shop_items)
    for entry in result:
        if entry[0] != null and entry[0].my_id_hash == item_hash:
            count += 1

    return count >= item.max_nb


# 取商店额外商品数据
func fengliu_get_shop_extra_item(item_hash: int) -> ItemParentData:
    var item = ItemService.get_element(get_items(), item_hash)
    if item != null:
        return item as ItemParentData

    var character = ItemService.get_element(get_characters(), item_hash)
    return character as ItemParentData


# 商店结果里是否已包含指定 id
func fengliu_shop_result_has_hash(result: Array, item_hash: int) -> bool:
    for entry in result:
        if entry.size() > 0 and entry[0] != null and entry[0].my_id_hash == item_hash:
            return true

    return false


# 随机取一角色
func fengliu_get_rand_shop_character(player_index: int, result: Array) -> ItemParentData:
    var current_character = RunData.get_player_character(player_index)
    var candidates = []
    for character in get_characters():
    
        if current_character != null and character.my_id_hash == current_character.my_id_hash:
            continue

        if fengliu_shop_result_has_hash(result, character.my_id_hash):
            continue

        candidates.push_back(character)

    return Utils.get_rand_element(candidates)


# 角色入店：把 [角色哈希, 概率, 初始价] 插到额外商品列表最前（概率由外层循环统一判定）
func fengliu_prepend_random_character(extra_effects: Array, player_index: int, result: Array) -> Array:
    var prepend_effects = RunData.get_player_effect(effect_fengliu_add_random_character_to_shop, player_index)
    if prepend_effects.size() == 0:
        return extra_effects

    var new_effects = extra_effects.duplicate()
    for effect in prepend_effects:
        var character = fengliu_get_rand_shop_character(player_index, result)
        if character == null:
            continue

        # 概率交给外层统一判定；第 3 项 = 商店初始价（0/缺省用角色自身 value）
        var shop_price = int(effect[2]) if effect.size() > 2 else 0
        new_effects.push_front([character.my_id_hash, effect[1], shop_price])

    return new_effects


# 道具属性改写
func fengliu_reset_item_stat(item, effect) -> ItemParentData:
    var new_item = item.duplicate()
    for item_effect_index in new_item.effects.size():
        var item_effect = new_item.effects[item_effect_index]
        if item_effect.key_hash != effect[0]:
            continue

        var new_item_effect = item_effect.duplicate()
        new_item_effect.key_hash = effect[1]
        new_item_effect.key = Keys.hash_to_string.get(effect[1], new_item_effect.key)
        new_item.effects[item_effect_index] = new_item_effect

    return new_item


# 扩展商店道具
func get_player_shop_items(wave: int, player_index: int, args: ItemServiceGetShopItemsArgs) -> Array:
    var custom_guaranteed = RunData.get_player_effect(effect_fengliu_guaranteed_shop_items, player_index)

    var result
    if custom_guaranteed.size() > 0:
        result = fengliu_guaranteed_shop_items(custom_guaranteed, wave, player_index, args)
    else:
        result = .get_player_shop_items(wave, player_index, args)
    
    var extra_shop_item_chance_effects = RunData.get_player_effect(effect_fengliu_extra_shop_item_chance, player_index)
    extra_shop_item_chance_effects = fengliu_prepend_random_character(extra_shop_item_chance_effects, player_index, result)

    var guaranteed_count = custom_guaranteed.size() + RunData.get_player_effect(Keys.guaranteed_shop_items_hash, player_index).size()
    var extra_shop_item_index = 0
    if guaranteed_count >= result.size():
        extra_shop_item_index = 3
    else:
        extra_shop_item_index = guaranteed_count

    for effect in extra_shop_item_chance_effects:
        if not Utils.get_chance_success(effect[1] / 100.0):
            continue

        if extra_shop_item_index >= result.size():
            break

        if fengliu_shop_slot_reached_limit(effect[0], args.owned_and_shop_items, result):
            continue

        var item_data = fengliu_get_shop_extra_item(effect[0]).duplicate()
        # 额外商品可带初始价（覆盖角色/道具自身 value）
        if effect.size() > 2 and int(effect[2]) > 0:
            item_data.value = int(effect[2])
        result[extra_shop_item_index] = [item_data, wave]
        extra_shop_item_index += 1

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


# 扩展随机道具
func _get_rand_item_for_wave(wave: int, player_index: int, type: int, args: GetRandItemForWaveArgs) -> ItemParentData:
    var effects = RunData.get_player_effects(player_index)
    var item = ._get_rand_item_for_wave(wave, player_index, type, args)

    if effects[fengliu_wanted_item_tag_chance_hash] > 0:
        item = fengliu_get_rand_item_for_wave(wave, player_index, type, args)
    elif effects.has(effect_fengliu_extra_wanted_item_tag) and effects[effect_fengliu_extra_wanted_item_tag].size() > 0:
        item = fengliu_get_rand_item_for_wave(wave, player_index, type, args)
    
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

    # 复制 item，并逐个复制需要重随的效果，避免污染商店池里的模板资源
    var new_item = item.duplicate()
    if has_reroll_effect:
        var new_effects = []
        for effect in new_item.effects:
            if _fengliu_effect_needs_reroll(effect):
                effect = effect.duplicate()
                effect.fengliu_roll_effect(player_index)
            new_effects.append(effect)

        new_item.effects = new_effects

    effects = RunData.get_player_effect(effect_fengliu_reset_item_stat, player_index)
    if effects.size() > 0:
        for effect in effects:
            new_item = ItemService.fengliu_reset_item_stat(new_item, effect)

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


func _fengliu_get_upgrades_pool(pool_id_hash: int, player_index: int) -> Array:
    var upgrades_ids = []
    var build_pool = []
    var banned_upgrades = RunData.get_player_character(player_index).banned_upgrades

    for stat_id_hash in fengliu_upgrades_pools[pool_id_hash]:
        var upgrade_id = fengliu_get_upgrade_data_id_hash_by_stat(stat_id_hash)
        if not Keys.hash_to_string[upgrade_id] in banned_upgrades:
            build_pool.append(upgrade_id)

    while true:
        if upgrades_ids.size() >= 4:
            break
        
        var upgrade_id = Utils.get_rand_element(build_pool)
        if upgrade_id in upgrades_ids and build_pool.size() > 4:
            continue
        
        upgrades_ids.append(upgrade_id)

    var upgrades = []
    var level = RunData.get_player_level(player_index)
    for id_hash in upgrades_ids:
        upgrades.append(fengliu_get_fixed_upgrade_data(level, player_index, id_hash))

    return upgrades


# 扩展生成升级项
func get_upgrades(level: int, number: int, old_upgrades: Array, player_index: int) -> Array:
    var is_fengliu_upgrades_pool = false
    if level in fengliu_upgrades_pools:
        is_fengliu_upgrades_pool = true
    
    var upgrades = []
    if not is_fengliu_upgrades_pool:
        upgrades = .get_upgrades(level, number, old_upgrades, player_index)
        
    # 有固定升级项效果则替换升级项
    var effects = RunData.get_player_effect(effect_fengliu_get_fixed_upgrade, player_index)
    if effects.size() > 0 and effects[0].all_fixed_upgrade_id_hashs.size() >= 4:
        if is_fengliu_upgrades_pool:
            level = RunData.get_player_level(player_index)

        upgrades = fengliu_get_fixed_upgrade(level, effects[0], player_index)

    if is_fengliu_upgrades_pool and effects.size() <= 0:
        upgrades = _fengliu_get_upgrades_pool(level, player_index)

    # 应用升级项品阶提升效果
    for effect in RunData.get_player_effect(effect_fengliu_up_upgrade_data_tier, player_index):
        upgrades = fengliu_up_upgrade_data_tier(effect, upgrades, player_index)
    
    effects = RunData.get_player_effect(effect_fengliu_reset_item_stat, player_index)
    if effects.size() > 0:
        for effect in effects:
            for index in upgrades.size():
                upgrades[index] = ItemService.fengliu_reset_item_stat(upgrades[index], effect)

    return upgrades


# 扩展道具效果修正：商店/掉落随机生成"被诅咒"的道具或武器后，
# 若为水壶则立即还原其收获产树效果，避免被诅咒改成"另一个效果"并放大 value
func apply_item_effect_modifications(item: ItemParentData, player_index: int) -> ItemParentData:
    # 先走原版的道具效果修正
    var new_item = .apply_item_effect_modifications(item, player_index)
    RunData.fengliu_normalize_cursed_effect(new_item)
    return new_item


# mod 魔改 _get_rand_item_for_wave 使其可以实现更复杂的操作
func fengliu_get_rand_item_for_wave(wave: int, player_index: int, type: int, args: GetRandItemForWaveArgs) -> ItemParentData:
	var player_character = RunData.get_player_character(player_index)
	var rand_wanted = randf()
	var item_tier = get_tier_from_wave(wave, player_index, args.increase_tier)

	if args.fixed_tier != - 1:
		item_tier = args.fixed_tier

	if type == TierData.WEAPONS:
		var min_weapon_tier = RunData.get_player_effect(Keys.min_weapon_tier_hash, player_index)
		var max_weapon_tier = RunData.get_player_effect(Keys.max_weapon_tier_hash, player_index)
		item_tier = clamp(item_tier, min_weapon_tier, max_weapon_tier)

	var banned_items = RunData.players_data[player_index].banned_items
	var pool = get_pool(item_tier, type)
	var backup_pool = get_pool(item_tier, type)
	var items_to_remove = []

	if banned_items.size() > 0:
		for item_id in banned_items:
			if item_id is String:
				var item_id_hash = Keys.generate_hash(item_id)
				pool = remove_element_by_id(pool, item_id_hash)
				backup_pool = remove_element_by_id(backup_pool, item_id_hash)
			else:
				pool = remove_element_by_id(pool, item_id)
				backup_pool = remove_element_by_id(backup_pool, item_id)
	
	for shop_item in args.excluded_items:
		pool = remove_element_by_id_with_item(pool, shop_item[0])
		backup_pool = remove_element_by_id_with_item(pool, shop_item[0])

	if type == TierData.WEAPONS:
		var bonus_chance_same_weapon_set = max(0, (MAX_WAVE_ONE_WEAPON_GUARANTEED + 1 - RunData.current_wave) * (BONUS_CHANCE_SAME_WEAPON_SET / MAX_WAVE_ONE_WEAPON_GUARANTEED))
		var chance_same_weapon_set = CHANCE_SAME_WEAPON_SET + bonus_chance_same_weapon_set
		var bonus_chance_same_weapon = max(0, (MAX_WAVE_ONE_WEAPON_GUARANTEED + 1 - RunData.current_wave) * (BONUS_CHANCE_SAME_WEAPON / MAX_WAVE_ONE_WEAPON_GUARANTEED))
		var chance_same_weapon = CHANCE_SAME_WEAPON + bonus_chance_same_weapon

		var no_melee_weapons: bool = RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, player_index)
		var no_ranged_weapons: bool = RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, player_index)
		var no_duplicate_weapons: bool = RunData.get_player_effect_bool(Keys.no_duplicate_weapons_hash, player_index)
		var no_structures: bool = RunData.get_player_effect(Keys.remove_shop_items_hash, player_index).has(Keys.structure_hash)

		var player_sets: Array = RunData.get_player_sets(player_index)
		var unique_weapon_ids: Dictionary = RunData.get_unique_weapon_ids(player_index)

		for item in pool:
			if no_melee_weapons and item.type == WeaponType.MELEE:
				backup_pool = remove_element_by_id_with_item(backup_pool, item)
				items_to_remove.push_back(item)
				continue

			if no_ranged_weapons and item.type == WeaponType.RANGED:
				backup_pool = remove_element_by_id_with_item(backup_pool, item)
				items_to_remove.push_back(item)
				continue

			if no_duplicate_weapons:
				for weapon in unique_weapon_ids.values():
					
					if item.weapon_id_hash == weapon.weapon_id_hash and item.tier < weapon.tier:
						backup_pool = remove_element_by_id_with_item(backup_pool, item)
						items_to_remove.push_back(item)
						break

					
					elif item.my_id_hash == weapon.my_id_hash and weapon.upgrades_into == null:
						backup_pool = remove_element_by_id_with_item(backup_pool, item)
						items_to_remove.push_back(item)
						break

			if no_structures and EntityService.is_weapon_spawning_structure(item):
				backup_pool = remove_element_by_id_with_item(backup_pool, item)
				items_to_remove.append(item)

			if rand_wanted < chance_same_weapon:
				if not item.weapon_id in unique_weapon_ids:
					items_to_remove.push_back(item)
					continue

			elif rand_wanted < chance_same_weapon_set:
				var remove: = true
				for set in item.sets:
					if set.my_id_hash in player_sets:
						remove = false
				if remove:
					items_to_remove.push_back(item)
					continue

	elif type == TierData.ITEMS:
		var wanted_item_tag_chance = CHANCE_WANTED_ITEM_TAG
		if RunData.get_player_effects(player_index).has(Keys.stat_boosted_wanted_item_tag_hash) and RunData.get_player_effect_bool(Keys.stat_boosted_wanted_item_tag_hash, player_index):
			wanted_item_tag_chance = BOOSTED_WANTED_ITEM_TAG

        # 修改道具 tags 
		wanted_item_tag_chance += RunData.get_player_effect(fengliu_wanted_item_tag_chance_hash, player_index) / 100.0
		var wanted_tags: Array = player_character.wanted_tags.duplicate()
		# 旧档槽位里可能是标签哈希，统一还原成标签名后再比对
		for extra_wanted_tag in RunData.get_player_effect(effect_fengliu_extra_wanted_item_tag, player_index):
			var extra_wanted_tag_name: String = RunData.fengliu_resolve_item_tag_name(extra_wanted_tag)
			if extra_wanted_tag_name != "":
				wanted_tags.push_back(extra_wanted_tag_name)

		if Utils.get_chance_success(wanted_item_tag_chance) and wanted_tags.size() > 0:
			for item in pool:
				var has_wanted_tag = false

				for tag in item.tags:
					if wanted_tags.has(tag):
						has_wanted_tag = true
						break

				if not has_wanted_tag:
					items_to_remove.push_back(item)

		if args.forced_shop_tag != null:
			for item in pool:
				if not items_to_remove.has(item) and not item.tags.has(args.forced_shop_tag):
					items_to_remove.push_back(item)

		var remove_item_tags: Array = RunData.get_player_effect(Keys.remove_shop_items_hash, player_index)

		for tag_to_remove in remove_item_tags:
			for item in pool:
				if Keys.hash_to_string[tag_to_remove] in item.tags:
					items_to_remove.append(item)

		if RunData.current_wave < RunData.nb_of_waves:
			if player_character.banned_item_groups.size() > 0:
				for banned_item_group in player_character.banned_item_groups:

					if not banned_item_group in item_groups:
						print(str(banned_item_group) + " does not exist in ItemService.item_groups")
						continue

					for item in pool:
						
						
						if item_groups[banned_item_group].has(item.my_id):
							items_to_remove.append(item)

			if player_character.banned_items.size() > 0:
				for item in pool:
					
					
					if player_character.banned_items.has(item.my_id):
						items_to_remove.append(item)
		else:
			
			for item in pool:
				if banned_items_for_endless.has(item.my_id_hash):
					items_to_remove.append(item)

	var limited_items = get_limited_items(args.owned_and_shop_items)

	for key in limited_items:
		if limited_items[key][1] >= limited_items[key][0].max_nb:
			backup_pool = remove_element_by_id_with_item(backup_pool, limited_items[key][0])
			items_to_remove.push_back(limited_items[key][0])

	for item in items_to_remove:
		pool = remove_element_by_id_with_item(pool, item)

	var elt

	if pool.size() == 0:
		if backup_pool.size() > 0:
			elt = Utils.get_rand_element(backup_pool)
		else:
			elt = Utils.get_rand_element(_tiers_data[item_tier][type])
	else:
		elt = Utils.get_rand_element(pool)
		if elt.my_id_hash == Keys.item_axolotl_hash and randf() < 0.5:
			elt = Utils.get_rand_element(pool)

	if DebugService.force_item_in_shop != "" and randf() < 0.5:
		elt = get_element(get_items(), Keys.generate_hash(DebugService.force_item_in_shop))
		if elt == null:
			elt = get_element(get_weapons(), Keys.generate_hash(DebugService.force_item_in_shop))

	
	if elt.my_id_hash == Keys.item_axolotl_hash and elt.effects.size() > 0 and "stats_swapped" in elt.effects[0]:
		elt.effects[0].stats_swapped = []

	return apply_item_effect_modifications(elt, player_index)


func get_stat(stat_hash: int) -> StatData:
	var stat := .get_stat(stat_hash)
	if stat != null:
		return stat

	# 按物品套组注册表补查
	for update_data in update_data_list:
		if update_data == null or update_data.item_set == null:
			continue
		for set_stat in update_data.item_set.stats:
			if set_stat != null and set_stat.stat_hash == stat_hash:
				return set_stat

	return null


# 覆盖: 原版 init_elites_spawn 在难度 ≥ 4 时一次连抽 3 只精英，且每抽一只就从该池里移除一条；
func get_elites_from_zone(zone_id: int) -> Array:
	var zone_elites: Array = .get_elites_from_zone(zone_id)

	# 空池保持原样（调用方本就按「本区域没有精英」处理），只补齐 1~2 条的情况
	if zone_elites.size() == 0 or zone_elites.size() >= 3:
		return zone_elites

	var padded: Array = zone_elites.duplicate()
	while padded.size() < 3:
		padded.push_back(zone_elites[padded.size() % zone_elites.size()])

	return padded


func _fengliu_register_all_content() -> void:
	# 只注册一次
	if _fengliu_content_registered:
		return
        
	_fengliu_content_registered = true

	# 按目录分类收集，目录结构本身就是分类依据
	var content := {
		"characters": [],
		"items": [],
		"weapons": [],
		"sets": [],
		"upgrades": [],
	}

	for sub_dir_name in FENGLIU_DYNAMIC_CONTENT_SUBDIRS:
		_fengliu_collect_content_dir(FENGLIU_CONTENT_DIR + sub_dir_name, content)

	sets.append_array(content["sets"])
	upgrades.append_array(content["upgrades"])

	# 物品套组：角色 / 道具 / 武器 / 自定义属性
	var item_set := ItemSetData.new()
	item_set.my_id = FENGLIU_ITEM_SET_ID
	item_set.items = content["items"]
	item_set.weapons = content["weapons"]
	item_set.characters = content["characters"]
	item_set.stats = _fengliu_collect_mod_resources(stats)

	var update_data = load(FENGLIU_UPDATE_TRES)
	if update_data == null or not (update_data is UpdateData):
		ModLoaderLog.error("UpdateData tres missing or invalid: %s" % FENGLIU_UPDATE_TRES, FENGLIU_MOD_ID)
		return

	update_data.item_set = item_set
	update_data_list.push_back(update_data)

	# 激活套组 → 重建聚合缓存 → 读档前登记效果槽位 → 读档 → 补解锁 → 重建池
	ProgressData.refresh_active_update_data()
	invalidate_items_cache()
	invalidate_weapons_cache()

	for weapon in get_weapons():
		if weapon.upgrades_into != null:
			weapon.upgrades_into.previous_upgrade = weapon

	invalidate_characters_cache()
	_fengliu_hide_weapons_from_codex()
	# 套组注册后才进入 active_update_data，这里补一次 stat keys（vanilla 的 reset 在注册之前）
	Utils.reset_stat_keys()
	_fengliu_ensure_effect_slot_keys()
	ProgressData.load_game_file()
	_fengliu_finalize_content_pools()

	ModLoaderLog.info("Registered native content: characters=%d items=%d weapons=%d sets=%d upgrades=%d stats=%d."
		% [item_set.characters.size(), item_set.items.size(), item_set.weapons.size(),
			content["sets"].size(), content["upgrades"].size(), item_set.stats.size()], FENGLIU_MOD_ID)

	call_deferred("_fengliu_finalize_content_pools")


# 补齐「激活套组 → 重建缓存 → 默认解锁 → 商店/升级池」，可重复调用
func _fengliu_finalize_content_pools() -> void:
	ProgressData.refresh_active_update_data()
	invalidate_items_cache()
	invalidate_weapons_cache()
	invalidate_characters_cache()
	_fengliu_hide_weapons_from_codex()
	ProgressData.add_unlocked_by_default()
	init_unlocked_pool()


# 让指定武器家族在图鉴/道具套组里只保留最低阶（幂等；已有真实升级链的武器不动）
func _fengliu_hide_weapons_from_codex() -> void:
	var weapons_by_id := {}
	for weapon in get_weapons():
		if weapon != null:
			weapons_by_id[weapon.my_id] = weapon

	for base_id in FENGLIU_CODEX_HIDDEN_WEAPON_CHAIN:
		var base_weapon = weapons_by_id.get(base_id)
		var next_weapon = weapons_by_id.get(FENGLIU_CODEX_HIDDEN_WEAPON_CHAIN[base_id])
		if base_weapon == null or next_weapon == null:
			continue
		# 已有真实升级链（或已挂前阶）则不动
		if next_weapon.previous_upgrade != null or next_weapon.upgrades_into != null:
			continue
		next_weapon.previous_upgrade = base_weapon


# 读档前登记效果实例槽位（mod_main 已登记一次，这里幂等兜底，与本函数的读档顺序无关）
func _fengliu_ensure_effect_slot_keys() -> void:
	var mod_node = get_node_or_null("/root/ModLoader/FengLiu-FengAddMods")
	if mod_node != null and mod_node.has_method("_fengliu_register_effect_slot_keys"):
		mod_node._fengliu_register_effect_slot_keys()


# 递归收集目录里的 .tres，目录打不开只记错误、不中断其它目录
func _fengliu_collect_content_dir(dir_path: String, content: Dictionary) -> void:
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		ModLoaderLog.error("Failed to open content directory: %s" % dir_path, FENGLIU_MOD_ID)
		return

	# 先收齐条目名再排序，避免注册顺序随文件系统枚举顺序变化
	var entry_names := []
	var is_dir_by_name := {}
	dir.list_dir_begin(true, true)
	var file_name := dir.get_next()

	while file_name != "":
		entry_names.push_back(file_name)
		is_dir_by_name[file_name] = dir.current_is_dir()
		file_name = dir.get_next()

	dir.list_dir_end()
	entry_names.sort()

	# 子目录继续递归，.tres 交给分类函数，其余文件忽略
	for entry_name in entry_names:
		var full_path := dir_path.plus_file(entry_name)

		if is_dir_by_name[entry_name]:
			_fengliu_collect_content_dir(full_path, content)

		elif entry_name.get_extension() == "tres":
			_fengliu_collect_content_file(full_path, content)


func _fengliu_collect_content_file(file_path: String, content: Dictionary) -> void:
	var data = load(file_path)
	if data == null:
		ModLoaderLog.warning("Failed to load content resource: %s" % file_path, FENGLIU_MOD_ID)
		return

	if data is CharacterData:
		content["characters"].push_back(data)
	elif data is WeaponData:
		content["weapons"].push_back(data)
	elif data is SetData:
		content["sets"].push_back(data)
	elif data is UpgradeData:
		content["upgrades"].push_back(data)
	elif data is ConsumableData:
		return
	elif data is ItemData:
		content["items"].push_back(data)


# 只收集本 mod 目录下的资源，避免把原版内容重复塞进套组
func _fengliu_collect_mod_resources(pool: Array) -> Array:
	var result := []
	for element in pool:
		if element == null:
			continue
		if element.resource_path.begins_with(FENGLIU_MOD_DIR):
			result.push_back(element)
	return result


var fengliu_shop_item_count_hash = Keys.generate_hash("fengliu_shop_item_count")
var fengliu_shop_items_count_price_hash = Keys.generate_hash("fengliu_shop_items_count_price")


# 按「商店道具数量」效果裁剪商店数据（只处理纯数据，UI 同步由调用方负责）
func fengliu_trim_shop_item_count(items_data: Array, player_index: int) -> Array:
	var effects = RunData.get_player_effect(fengliu_shop_item_count_hash, player_index)
	
	# 无效果则不处理
	if effects.size() == 0:
		return items_data

	var effect = effects[0]
	var item_count: int = effect[1]

	# effect[3] 非 0 表示动态数量（effect[2]~effect[3] 区间，effect[4] 是否避开 0）
	if effect[3] != 0:
		item_count = NB_SHOP_ITEMS - fengliu_get_dynamic_value(effect[2], effect[3], effect[4])

	var locked_size := 0
	if player_index < RunData.locked_shop_items.size():
		locked_size = RunData.locked_shop_items[player_index].size()

	var final_count: int = item_count
	# 锁定格多于效果数量：优先保留锁定格，最多铺满
	if locked_size > final_count:
		if locked_size >= NB_SHOP_ITEMS:
			final_count = NB_SHOP_ITEMS
		else:
			final_count = min(NB_SHOP_ITEMS, locked_size + final_count)

	if final_count <= 0 or final_count >= items_data.size():
		return items_data

	var trimmed := []

	for index in range(final_count):
		trimmed.push_back(items_data[index])

	return trimmed



# 按缺少的格子加价（幂等：格子数量没变就不重复加）
func fengliu_apply_shop_item_count_price(items_data: Array, player_index: int) -> void :
	var effects = RunData.get_player_effects(player_index)
	var count_effects = RunData.get_player_effect(fengliu_shop_item_count_hash, player_index)

	# 无效果则不处理
	if count_effects.size() == 0:
		return

	var base_price: int = count_effects[0][5]

	# 未开启加价则不处理
	if base_price == 0:
		return

	if not effects.has(fengliu_shop_items_count_price_hash):
		effects[fengliu_shop_items_count_price_hash] = 0

	var prev_price: int = effects[fengliu_shop_items_count_price_hash]
	var new_price: int = base_price * (NB_SHOP_ITEMS - items_data.size())
	# 数量没变化则保持原样，避免重复刷新时叠加
	if new_price == prev_price:
		return

	effects[Keys.items_price_hash] = effects[Keys.items_price_hash] + abs(prev_price) + new_price
	effects[fengliu_shop_items_count_price_hash] = new_price


# 商店刷新重随：预报类效果 + 套装武器替换
func fengliu_roll_shop_rerolls(items_data: Array, player_index: int) -> void :
	for entry in items_data:
		if entry == null or entry[0] == null:
			continue
		var item = entry[0]
		if item.effects == null:
			continue
		for effect in item.effects:
			if effect == null:
				continue
			# 未生成哈希时按 custom_key 补算
			if effect.custom_key_hash == Keys.empty_hash and effect.custom_key != "":
				effect.custom_key_hash = Keys.generate_hash(effect.custom_key)
			if not _fengliu_effect_needs_reroll(effect):
				continue
			if effect.has_method("fengliu_roll_effect"):
				effect.fengliu_roll_effect(player_index)

	fengliu_roll_set_weapon_in_shop_data(items_data, player_index)


# 商店刷新重随：把非目标套装的武器替换为目标套装武器（纯数据版）
func fengliu_roll_set_weapon_in_shop_data(items_data: Array, player_index: int) -> void :
	var effects = RunData.get_player_effect(effect_fengliu_can_rand_set_weapon, player_index)
	# 无该效果则不处理
	if effects.size() == 0:
		return

	var locked_size := 0
	if player_index < RunData.locked_shop_items.size():
		locked_size = RunData.locked_shop_items[player_index].size()

	# 商店刷新带来的品阶提升
	var increase_tier := 0
	for increase_tier_effect in RunData.get_player_effect(Keys.increase_tier_on_reroll_hash, player_index):
		increase_tier = increase_tier_effect[1]
		break

	# 商店内道具 + 玩家已拥有道具，用于原版数量上限判定
	var owned_and_shop_items: Array = RunData.get_player_items(player_index).duplicate()
	for entry in items_data:
		if entry != null and entry[0] != null:
			owned_and_shop_items.push_back(entry[0])

	fengliu_roll_set_weapon_in_shop(items_data, locked_size, RunData.current_wave, player_index, owned_and_shop_items, increase_tier)


# 随机生成动态值（数量效果用）
static func fengliu_get_dynamic_value(stat_min_value: int, stat_max_value: int, stat_no_zero: bool) -> int:
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	# 为 0 时重新取值
	if dynamic_value == 0 and stat_no_zero:
		return fengliu_get_dynamic_value(stat_min_value, stat_max_value, stat_no_zero)
	return dynamic_value



# 物品套组显示兜底
func get_update_data_from_item(item_data: ItemParentData) -> UpdateData:
	var update_data = .get_update_data_from_item(item_data)
	if update_data != null:
		return update_data

	return get_update_data_by_item_id(item_data)

