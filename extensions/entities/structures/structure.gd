extends Structure


var effect_fengliu_structure_add_range = Keys.generate_hash("fengliu_structure_add_range")
var _player_range = 0
var _stats_max_range = 0


# 扩展构造物射程
func reload_data() -> void :
    .reload_data()
    if is_pet:
        return

    # 累加所有玩家的射程加成
    for player_index in RunData.get_player_count():
        var effects = RunData.get_player_effect(effect_fengliu_structure_add_range, player_index)
        if effects.size() > 0:
            _player_range += Utils.get_stat(effects[0][0], player_index)

    # 叠加到基础射程
    _stats_max_range = stats.max_range
    stats.max_range = _stats_max_range + _player_range
    _player_range = 0