extends Consumable


var effect_wave_end_not_pick_consumable = Keys.generate_hash("wave_end_not_pick_consumable")


func has_damage_effect() -> bool:
    for player_index in RunData.get_player_count():
        if RunData.get_player_effect(effect_wave_end_not_pick_consumable, player_index).size() == 0:
            continue
        return true

    return .has_damage_effect()