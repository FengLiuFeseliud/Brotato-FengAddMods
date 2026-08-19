extends Consumable


var effect_fengliu_wave_end_not_pick_consumable = Keys.generate_hash("fengliu_wave_end_not_pick_consumable")


# 扩展波次结束不拾取
func has_damage_effect() -> bool:
    # 任一玩家持有该效果即可
    for player_index in RunData.get_player_count():
        if RunData.get_player_effect(effect_fengliu_wave_end_not_pick_consumable, player_index).size() == 0:
            continue
        return true

    return .has_damage_effect()