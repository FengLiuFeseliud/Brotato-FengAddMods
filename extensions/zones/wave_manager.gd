extends WaveManager

var effect_minecraft = Keys.generate_hash("minecraft")
var minecreft_zone_data = []


func init_minecreft_zone(zone_data: ZoneData) -> void:
    if minecreft_zone_data.size() == 0:
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/stone/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/iron_ore/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/diamond_ore/group.tres"))
        minecreft_zone_data.append(preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_minecreft/obsidian/group.tres"))

    for zone in minecreft_zone_data:
        zone_data.groups_data_in_all_waves.push_back(zone)


func init(p_wave_timer: Timer, zone_data: ZoneData, wave_data: Resource) -> void :
    for player_index in RunData.get_player_count():
        if RunData.get_player_effect(effect_minecraft, player_index).size() == 0:
            continue
        
        init_minecreft_zone(zone_data)
        break
    
    .init(p_wave_timer, zone_data, wave_data)