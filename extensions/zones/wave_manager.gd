extends WaveManager

var effect_fengliu_minecraft = Keys.generate_hash("fengliu_minecraft")
var minecreft_zone_data = []


func fengliu_init_minecreft_zone(zone_data: ZoneData) -> void:
    if minecreft_zone_data.size() == 0:
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/stone/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/iron_ore/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/diamond_ore/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/obsidian/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/lapis_ore/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/emerald_ore/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/villager/group.tres"))

    for zone in minecreft_zone_data:
        zone_data.groups_data_in_all_waves.push_back(zone)


func init(p_wave_timer: Timer, zone_data: ZoneData, wave_data: Resource) -> void :
    for player_index in RunData.get_player_count():
        if RunData.get_player_effect(effect_fengliu_minecraft, player_index).size() == 0:
            continue
        
        # 向关卡注入 mc 矿石
        fengliu_init_minecreft_zone(zone_data)
        break
    
    .init(p_wave_timer, zone_data, wave_data)