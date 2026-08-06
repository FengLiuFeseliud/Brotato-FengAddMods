extends Player


var effect_consumable_stats = Keys.generate_hash("consumable_stats")
var effect_stat_hit_protection = Keys.generate_hash("stat_hit_protection")
var effect_regen_hit_protection = Keys.generate_hash("regen_hit_protection")
var effect_temp_stats_on_hit_protection = Keys.generate_hash("temp_stats_on_hit_protection")


var _max_hit_protection = 0
var _regen_hit_protection_timer = null
var _player_ui = null
var _regen_hit_protection = []


static func get_dynamic_chance(init_chance: int, add_chance: int = 0, stat_count: int = 0) -> float:
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	if dynamic_chance > 100:
		return 100.0 / 100
		
	return dynamic_chance / 100


func _ready() -> void :
    var effects = RunData.get_player_effect(effect_stat_hit_protection, player_index)
    if effects.size() > 0:
        var effect = effects[0]
        _hit_protection += int(Utils.get_stat(effect[0], player_index) / effect[1])
        _max_hit_protection = _hit_protection

    
    effects = RunData.get_player_effect(effect_regen_hit_protection, player_index)
    if effects.size() == 0:
	    return
    
    _regen_hit_protection_timer = FixedTimer.new(effects[0][2])
    _regen_hit_protection = effects[0]


func get_player_ui() -> PlayerUIElements:
    if _player_ui == null:
        var main = get_node("/root/Main")
        _player_ui = main._players_ui[player_index]
    
    return _player_ui


func _physics_process(delta: float) -> void :
    if _regen_hit_protection_timer != null and _regen_hit_protection_timer.try_loop(delta) > 0:
        on_regen_hit_protection()


func take_damage(value: int, args: TakeDamageArgs) -> Array:
    if _regen_hit_protection_timer != null and (_invincibility_timer.is_stopped() or args.bypass_invincibility):
        if _regen_hit_protection_timer.is_stopped():
            _regen_hit_protection_timer.start()

        for effect in RunData.get_player_effect(effect_temp_stats_on_hit_protection, player_index):
            TempStats.add_stat(effect[0], effect[1], player_index)

    return .take_damage(value, args)


func on_regen_hit_protection() -> void:
    if _hit_protection >= _max_hit_protection:
        _regen_hit_protection_timer.stop()
        return
    
    var stat_count = Utils.get_stat(_regen_hit_protection[0], player_index)
    if not Utils.get_chance_success(get_dynamic_chance(_regen_hit_protection[1], _regen_hit_protection[3], stat_count)):
        return

    _hit_protection += 1
    if get_player_ui() != null:
        get_player_ui().update_hit_protection_count(self, _hit_protection)


func on_consumable_picked_up(_consumable_data: ConsumableData) -> void :
    var effects = RunData.get_player_effect(effect_consumable_stats, player_index)
    if effects.size() > 0:
        for effect in effects:
            RunData.add_stat(effect[0], effect[1], player_index)