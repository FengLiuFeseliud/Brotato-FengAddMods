extends WaveManager

var effect_fengliu_minecraft = Keys.generate_hash("fengliu_minecraft")
var minecreft_zone_data = []


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


# 应用下一波换怪：把 x 的场景替换成 y 的场景
func fengliu_apply_wave_swap_enemies() -> void:
    if RunData._wave_swap_enemies.size() == 0:
        return

    for swap in RunData._wave_swap_enemies:
        var from_path = swap[0]
        var to_path = swap[2]
        for group in current_wave_data.groups_data:
            for unit in group.wave_units_data:
                if unit.unit_scene != null and unit.unit_scene.resource_path == from_path:
                    unit.unit_scene = load(to_path)

    RunData._wave_swap_enemies.clear()


