extends Player


var consumable_stats = Keys.generate_hash("consumable_stats")


func on_consumable_picked_up(_consumable_data: ConsumableData) -> void :
    var effects = RunData.get_player_effect(consumable_stats, player_index)
    if effects.size() > 0:
        for effect in effects:
            RunData.add_stat(effect[0], effect[1], player_index)