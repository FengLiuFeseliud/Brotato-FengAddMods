extends Turret


var effect_fengliu_turret_prioriy_attack_highest_hp = Keys.generate_hash("fengliu_turret_prioriy_attack_highest_hp")
var effect_fengliu_turret_copy = Keys.generate_hash("fengliu_turret_copy")

var _hp_current_target = false
var _entity_spawner = null
var _data = null
var _turret_copy_effects = []


static func get_dynamic_chance(init_chance: int, add_chance: int = 100, stat_count: int = 0) -> float:
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	if dynamic_chance > 100:
		return 100 / 100.0
		
	return dynamic_chance / 100.0


func _ready():
    for player_index in RunData.get_player_count():
        if RunData.get_player_effect(effect_fengliu_turret_prioriy_attack_highest_hp, player_index).size() > 0:
            _hp_current_target = true

        var effects = RunData.get_player_effect(effect_fengliu_turret_copy, player_index)
        if effects.size() > 0:
            _turret_copy_effects.append([effects[0], player_index])


func get_highest_hp_target(targets: Array, from: Vector2, min_distance: float = 0) -> Array:
    var dist_to_target = 0
    var best_target = [null, 99999999] 
    var max_hp = -1.0
    
    min_distance = min_distance * min_distance

    for target in targets:
        dist_to_target = target.global_position.distance_squared_to(from)
        if dist_to_target < min_distance:
            continue

        if target.max_stats.health > max_hp:
            max_hp = target.max_stats.health
            best_target = [target, dist_to_target]

    if best_target[0] != null:
        best_target[1] = sqrt(best_target[1])
        return best_target

    return best_target

func _physics_process(delta):
    if not _hp_current_target:
        ._physics_process(delta)
        return


    ._physics_process(delta)
    _current_target = get_highest_hp_target(_targets_in_range, global_position, stats.min_range)


func set_data(data: Resource) -> void :
    .set_data(data)
    _data = data


func get_entity_spawner() -> EntitySpawner:
    if _entity_spawner != null:
        return _entity_spawner
    
    var main_scene = get_tree().current_scene
    if main_scene and main_scene.get("_entity_spawner") != null:
        _entity_spawner = main_scene.get("_entity_spawner")
    
    return _entity_spawner


func can_copy_turret(target: Node, _turret_copy_effect: Array, player_index: int) -> bool :
    var current_frame = Engine.get_physics_frames()
    if target.has_meta("turret_spawn_frame") and target.get_meta("turret_spawn_frame") == current_frame:
        return false
    target.set_meta("turret_spawn_frame", current_frame)

    var stat_count = Utils.get_stat(_turret_copy_effect[0], player_index)
    if not Utils.get_chance_success(get_dynamic_chance(_turret_copy_effect[1], _turret_copy_effect[2], stat_count)):
        return false

    return true


func copy_turret(target: Node) -> void:
    var pos = get_entity_spawner().get_spawn_pos_in_area(target.global_position, 100)
    var queue = get_entity_spawner().queues_to_spawn_structures[player_index]
    queue.push_back([EntityType.STRUCTURE, _data.scene, pos, _data])


func on_target_died(target: Node, _args: Entity.DieArgs) -> void :
    .on_target_died(target, _args)

    if get_entity_spawner() == null or _turret_copy_effects.size() == 0:
        return

    for  _turret_copy_effect in _turret_copy_effects:
        if not can_copy_turret(target, _turret_copy_effect[0], _turret_copy_effect[1]):
            continue

        copy_turret(target)