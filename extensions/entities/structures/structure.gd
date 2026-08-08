extends Structure


var effect_structure_add_range = Keys.generate_hash("structure_add_range")
var _player_range = 0
var _stats_max_range = 0


func reload_data() -> void :
    .reload_data()
    if is_pet:
        return

    for player_index in RunData.get_player_count():
        var effects = RunData.get_player_effect(effect_structure_add_range, player_index)
        if effects.size() > 0:
            _player_range += Utils.get_stat(effects[0][0], player_index)

    _stats_max_range = stats.max_range
    stats.max_range = _stats_max_range + _player_range
    _player_range = 0