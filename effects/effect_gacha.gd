class_name Gacha
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_null_effect.gd"


export(int) var boss_chance = 0
export(int) var legendary_chance = 0
export(int) var cost_gold = 0
export(float) var wave_inflation_rate
# 商店背包刷新排队标记
var _fengliu_shop_refresh_queued := {}


static func get_id() -> String:
	return "fengliu_gacha"


func get_box_cost() -> int:
    return int(cost_gold * (1.0 + (max(1, RunData.current_wave) - 1) * wave_inflation_rate))


# 抽到 boss 给下一波排一个随机精英
func add_boss_for_next_wave(player_index: int) -> void:
	var elite = Utils.get_rand_element(ItemService.get_elites_from_zone(ZoneService.current_zone.my_id))
	if elite == null:
		return

	RunData.get_player_effects(player_index)[Keys.extra_enemies_next_wave_hash].append([
		"res://zones/common/elite/group_elite.tres",
		1,
		elite.my_id_hash
	])


func add_item(tier: int, player_index: int):
    var owned_items: Array = RunData.get_player_items(player_index)
    for locked_item in RunData.get_player_locked_shop_items(player_index):
        if locked_item[0] is ItemData:
            owned_items.push_back(locked_item[0])
    
    var args = ItemService.GetRandItemForWaveArgs.new()
    args.owned_and_shop_items = owned_items
    args.fixed_tier = tier

    RunData.add_item(ItemService._get_rand_item_for_wave(RunData.current_wave, player_index, ItemService.TierData.ITEMS, args), player_index)
    # 抽到的道具需要立刻显示在商店背包里
    _fengliu_refresh_shop_items(player_index)
    RunData.add_tracked_value(player_index, RunData.fengliu_item_gacha_hash, 1)


# 当前商店节点（非商店场景返回 null）
func _fengliu_get_shop():
    var tree = RunData.get_tree()
    if tree == null:
        return null

    var scene = tree.current_scene
    if scene != null and scene.has_method("_get_gear_container"):
        return scene

    return null


# 请求刷新商店背包（非商店场景静默跳过）
func _fengliu_refresh_shop_items(player_index: int) -> void:
    var shop = _fengliu_get_shop()
    if shop == null:
        return
        
    if _fengliu_shop_refresh_queued.get(player_index, false):
        return

    _fengliu_shop_refresh_queued[player_index] = true
    call_deferred("_fengliu_do_refresh_shop_items", player_index)


func _fengliu_do_refresh_shop_items(player_index: int) -> void:
    _fengliu_shop_refresh_queued[player_index] = false

    var shop = _fengliu_get_shop()
    if shop == null:
        return

    # 商店自己的 _get_gear_container 已处理单机/联机分玩家容器
    shop._get_gear_container(player_index).set_items_data(RunData.get_player_items(player_index))


func apply(player_index: int) -> void:
    RunData.add_gold( - get_box_cost() * value, player_index)

    # 幸运折算：每 100 点幸运 = +1 个百分点出红概率
    var luck = Utils.get_stat(Keys.stat_luck_hash, player_index) / 100.0
    for _i in value:
        # 抽到 boss
        if Utils.get_chance_success(boss_chance / 100.0):
            add_boss_for_next_wave(player_index)
            continue

        # 抽到红箱
        if Utils.get_chance_success((legendary_chance + luck) / 100.0):
            add_item(Tier.LEGENDARY, player_index)
            continue

        # 什么也没抽到
        add_item(Tier.DANGER_0, player_index)


func get_args(player_index: int) -> Array:
    var luck = Utils.get_stat(Keys.stat_luck_hash, player_index) / 100.0
    return [str(get_box_cost() * value), str(value), str(legendary_chance + int(luck)), str(boss_chance)]