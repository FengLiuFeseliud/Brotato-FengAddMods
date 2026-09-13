extends Turret


var _hp_current_target = false
var _entity_spawner = null
var _data = null
var _turret_copy_effects = []


# 扩展炮塔效果检测
func _ready():
    # 检测玩家的炮塔相关效果
    for player_index in RunData.get_player_count():
        if RunData.get_player_effect(FengLiuKeys.effect_fengliu_turret_prioriy_attack_highest_hp(), player_index).size() > 0:
            _hp_current_target = true

        var effects = RunData.get_player_effect(FengLiuKeys.effect_fengliu_turret_copy(), player_index)
        if effects.size() > 0:
            _turret_copy_effects.append([effects[0], player_index])


# 查找血量最高的目标
func fengliu_get_highest_hp_target(targets: Array, from: Vector2, min_distance: float = 0) -> Array:
    var dist_to_target = 0
    var best_target = [null, 99999999] 
    var max_hp = -1.0
    
    min_distance = min_distance * min_distance

    # 遍历目标找血量最高者
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

# 扩展优先攻击最高血量
func _physics_process(delta):
    # 未启用则走原逻辑
    if not _hp_current_target:
        ._physics_process(delta)
        return


    ._physics_process(delta)
    # 切换为血量最高目标
    _current_target = fengliu_get_highest_hp_target(_targets_in_range, global_position, stats.min_range)


# 扩展设置炮塔数据
func set_data(data: Resource) -> void :
    .set_data(data)
    _data = data


# 获取实体生成器
func fengliu_get_entity_spawner() -> EntitySpawner:
    if _entity_spawner == null:
        _entity_spawner = FengLiuUtils.get_entity_spawner()

    return _entity_spawner


# 判断是否复制炮塔
func fengliu_can_copy_turret(target: Node, _turret_copy_effect: Array, player_index: int) -> bool :
    var current_frame = Engine.get_physics_frames()
    # 同帧已复制过则跳过
    if target.has_meta("turret_spawn_frame") and target.get_meta("turret_spawn_frame") == current_frame:
        return false
    target.set_meta("turret_spawn_frame", current_frame)

    var stat_count = Utils.get_stat(_turret_copy_effect[0], player_index)
    # 按概率判断
    if not Utils.get_chance_success(FengLiuUtils.get_dynamic_chance_ratio(_turret_copy_effect[1], _turret_copy_effect[2], stat_count)):
        return false

    return true


# 复制炮塔
func fengliu_copy_turret(target: Node) -> void:
    var pos = fengliu_get_entity_spawner().get_spawn_pos_in_area(target.global_position, 100)
    var queue = fengliu_get_entity_spawner().queues_to_spawn_structures[player_index]
    # 加入生成队列
    queue.push_back([EntityType.STRUCTURE, _data.scene, pos, _data])


# 扩展目标死亡复制
func on_target_died(target: Node, _args: Entity.DieArgs) -> void :
    .on_target_died(target, _args)

    # 无条件复制则返回
    if fengliu_get_entity_spawner() == null or _turret_copy_effects.size() == 0:
        return

    # 逐个效果判断
    for  _turret_copy_effect in _turret_copy_effects:
        if not fengliu_can_copy_turret(target, _turret_copy_effect[0], _turret_copy_effect[1]):
            continue

        fengliu_copy_turret(target)