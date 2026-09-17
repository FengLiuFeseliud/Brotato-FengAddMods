extends WaveManager

var effect_fengliu_minecraft = Keys.generate_hash("fengliu_minecraft")
var effect_fengliu_swap_enemie = Keys.generate_hash("fengliu_swap_enemie")
var effect_fengliu_extra_aliens = Keys.generate_hash("fengliu_extra_aliens")


var minecreft_zone_data = []
# 下一波敌人替换记录（由本局 WaveManager 持有，退出/重建场景后自动丢弃，不会跨局残留）
var _wave_swap_enemies = []


# 注入我的世界矿石组
func fengliu_init_minecreft_zone(zone_data: ZoneData) -> void:
    # 首次加载矿石组资源
    if minecreft_zone_data.size() == 0:
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/stone/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/iron_ore/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/diamond_ore/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/obsidian/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/lapis_ore/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/emerald_ore/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/villager/group.tres"))

    # 注入全部矿石组
    for zone in minecreft_zone_data:
        zone_data.groups_data_in_all_waves.push_back(zone)


# 应用下一波换怪：把 x 的场景替换成 y 的场景
func fengliu_apply_wave_swap_enemies() -> void:
    # 从玩家身上已购买/获得的预报道具效果（SwapEnemies）中收集本轮替换记录，
    _wave_swap_enemies.clear()
    for player_index in RunData.get_player_count():
        for swap_effect in RunData.get_player_effect(effect_fengliu_swap_enemie, player_index):
            if swap_effect.wave_enemy_x_id != "" and swap_effect.wave_enemy_y_id != "":
                _wave_swap_enemies.append([swap_effect.wave_enemy_x, swap_effect.wave_enemy_x_id, swap_effect.wave_enemy_y, swap_effect.wave_enemy_y_id])

    # 无替换记录则跳过
    if _wave_swap_enemies.size() == 0:
        return

    # 遍历当前波次的敌群，替换匹配的敌人
    for group_index in range(current_wave_data.groups_data.size()):
        var group = current_wave_data.groups_data[group_index]
        var new_units = group.wave_units_data.duplicate()
        var replaced = false

        for unit_index in range(new_units.size()):
            var new_unit = new_units[unit_index]
            for swap in _wave_swap_enemies:
                var from_path = swap[0]
                var to_path = swap[2]
                # 命中被替换的敌人场景则替换
                if new_unit.unit_scene != null and new_unit.unit_scene.resource_path == from_path:
                    var replaced_unit = new_unit.duplicate()
                    replaced_unit.unit_scene = load(to_path)
                    new_unit = replaced_unit
                    replaced = true

            if new_unit != new_units[unit_index]:
                new_units[unit_index] = new_unit

        # 有替换则整组替换
        if replaced:
            var new_group = group.duplicate()
            new_group.wave_units_data = new_units
            current_wave_data.groups_data[group_index] = new_group


# 波次内额外生成指定敌人（组数可随属性成长）
func fengliu_extra_aliens(player_index: int, effect: Array) -> void:
    var extra_alien_groups = effect[2]
    # 额外组数随属性提升
    if effect[0] != Keys.empty_hash:
        extra_alien_groups += int(Utils.get_stat(effect[0], player_index) * (effect[3] / 100.0))

    # 复制敌人组并按随机时机插入当前波次
    for i in extra_alien_groups:
        var new_group = effect[1].duplicate()
        new_group.spawn_timing = rand_range(5, wave_timer.time_left - 10)
        current_wave_data.groups_data.push_back(new_group)


# 扩展初始化
func init(p_wave_timer: Timer, zone_data: ZoneData, wave_data: Resource) -> void :
    for player_index in RunData.get_player_count():
        if RunData.get_player_effect(effect_fengliu_minecraft, player_index).size() == 0:
            continue
        
        # 向关卡注入 mc 矿石
        fengliu_init_minecreft_zone(zone_data)
        break
    
    .init(p_wave_timer, zone_data, wave_data)
    fengliu_apply_wave_swap_enemies()
    for player_index in RunData.get_player_count():
        for effect in RunData.get_player_effect(effect_fengliu_extra_aliens, player_index):
            fengliu_extra_aliens(player_index, effect)