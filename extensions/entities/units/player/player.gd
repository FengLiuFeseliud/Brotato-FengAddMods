extends Player


var effect_consumable_stats = Keys.generate_hash("consumable_stats")
var effect_box_stats = Keys.generate_hash("box_stats")
var effect_stat_hit_protection = Keys.generate_hash("stat_hit_protection")
var effect_regen_hit_protection = Keys.generate_hash("regen_hit_protection")
var effect_temp_stats_on_hit_protection = Keys.generate_hash("temp_stats_on_hit_protection")
var effect_not_moving_explosion = Keys.generate_hash("not_moving_explosion")
var effect_can_one_not_moving_explosion = Keys.generate_hash("can_one_not_moving_explosion")
var effect_picked_up_consumable_add_size = Keys.generate_hash("picked_up_consumable_add_size")


var _max_hit_protection = 0
var _regen_hit_protection_timer = null
var _player_ui = null
var _regen_hit_protection = []
var _not_moving_explosion_timer
var _can_not_moving_explosio = false
var _clean_up_room_timer
var _exploding_on_clean_up_room
var _scale_value = 1 


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
    if effects.size() > 0:
        _regen_hit_protection_timer = FixedTimer.new(effects[0][2])
        _regen_hit_protection = effects[0]

    effects = RunData.get_player_effect(effect_not_moving_explosion, player_index)
    if effects.size() > 0:
        _not_moving_explosion_timer = FixedTimer.new(effects[0].wait_time)
        _clean_up_room_timer = FixedTimer.new(1)
        _can_not_moving_explosio = false
        _exploding_on_clean_up_room = effects[0].exploding_on_clean_up_room


func get_player_ui() -> PlayerUIElements:
    if _player_ui == null:
        var main = get_node("/root/Main")
        _player_ui = main._players_ui[player_index]
    
    return _player_ui


func _physics_process(delta: float) -> void :
    if _regen_hit_protection_timer != null and _regen_hit_protection_timer.try_loop(delta) > 0:
        on_regen_hit_protection()

    if _not_moving_explosion_timer != null and _not_moving_explosion_timer.try_loop(delta) > 0:
        on_moving_explosion_timeout()

    if _clean_up_room_timer != null and _clean_up_room_timer.try_loop(delta) > 0:
        on_clean_up_room()
    

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


func set_scale_size(gain: float) -> void:
    _scale_value += _scale_value * (gain / 100.0)
    if _scale_value > 20:
        _scale_value = 20

    scale = Vector2(_scale_value, _scale_value)


func on_consumable_picked_up(consumable_data: ConsumableData) -> void :
    var effects = RunData.get_player_effect(effect_consumable_stats, player_index)
    if effects.size() > 0:
        for effect in effects:
            RunData.add_stat(effect[0], effect[1], player_index)

    effects = RunData.get_player_effect(effect_box_stats, player_index)
    if effects.size() > 0 and (consumable_data.my_id_hash == Keys.consumable_item_box_hash 
            or consumable_data.my_id_hash == Keys.consumable_legendary_item_box_hash):
        for effect in effects:
            RunData.add_stat(effect[0], effect[1], player_index)

    effects = RunData.get_player_effect(effect_picked_up_consumable_add_size, player_index)
    if effects.size() > 0: 
        set_scale_size(effects[0][0])

    .on_consumable_picked_up(consumable_data)


func on_clean_up_room():
    if not _not_moving_explosion_timer.is_stopped():
        _not_moving_explosion_timer.stop()
    
    if not _clean_up_room_timer.is_stopped():
        _clean_up_room_timer.stop()
    
    var main = Utils.get_scene_node()
    if main._entity_spawner.get_nb_bosses_and_elites_alive() == 0:
        main.clean_up_room()
    elif RunData.get_player_effect(effect_can_one_not_moving_explosion, player_index).size() > 0:
        if not main._end_wave_timer.is_stopped():
            main._end_wave_timer.stop()
        main._cleaning_up = false
        _take_damage_args.dodgeable = false
        _take_damage_args.armor_applied = false
        _take_damage_args.bypass_invincibility = true
        _take_damage_args.from = self
        var _dmg_taken = take_damage(int(Utils.get_stat(Keys.stat_max_hp_hash, player_index)), _take_damage_args)

func on_moving_explosion_timeout():
    var effects = RunData.get_player_effect(effect_not_moving_explosion, player_index)
    if effects.size() > 0 and not effects[0] is int:
        RunData.handle_explode_effect(effects[0].key_hash, global_position, player_index)

    if _exploding_on_clean_up_room:
        _clean_up_room_timer.start()


func check_not_moving_stats(movement: Vector2) -> void :
    if dead:
        return

    .check_not_moving_stats(movement) 
    if not (movement.x == 0 and movement.y == 0) or _not_moving_explosion_timer == null or not _can_not_moving_explosio:
        return
    
    if _not_moving_explosion_timer.is_stopped():
        _not_moving_explosion_timer.start()


func check_moving_stats(movement: Vector2) -> void :
    if dead:
        return

    .check_moving_stats(movement)
    if not (movement.x != 0 or movement.y != 0) or _not_moving_explosion_timer == null:
        return

    _can_not_moving_explosio = true
    if not _not_moving_explosion_timer.is_stopped():
        _not_moving_explosion_timer.stop()