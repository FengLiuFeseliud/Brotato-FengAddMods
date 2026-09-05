extends Player


var effect_fengliu_consumable_stats = Keys.generate_hash("fengliu_consumable_stats")
var effect_fengliu_effect_box_stats = Keys.generate_hash("fengliu_box_stats")
var effect_fengliu_effect_stat_hit_protection = Keys.generate_hash("fengliu_stat_hit_protection")
var effect_fengliu_regen_hit_protection = Keys.generate_hash("fengliu_regen_hit_protection")
var effect_fengliu_temp_stats_on_hit_protection = Keys.generate_hash("fengliu_temp_stats_on_hit_protection")
var effect_fengliu_not_moving_explosion = Keys.generate_hash("fengliu_not_moving_explosion")
var effect_fengliu_can_one_not_moving_explosion = Keys.generate_hash("fengliu_can_one_not_moving_explosion")
var effect_fengliu_picked_up_consumable_add_size = Keys.generate_hash("fengliu_picked_up_consumable_add_size")


var _max_hit_protection = 0
var _regen_hit_protection_timer = null
var _player_ui = null
var _regen_hit_protection = []
var _not_moving_explosion_timer
var _can_not_moving_explosio = false
var _clean_up_room_timer
var _exploding_on_clean_up_room
var _scale_value = 1 


# 计算动态概率
static func fengliu_get_dynamic_chance(init_chance: int, add_chance: int = 0, stat_count: int = 0) -> float:
	# 基础概率 + 属性数 * 每点加成
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	# 上限 100
	if dynamic_chance > 100:
		return 100.0 / 100
		
	return dynamic_chance / 100


# 扩展防护效果初始化
func _ready() -> void :
    # 配置防护值
    var effects = RunData.get_player_effect(effect_fengliu_effect_stat_hit_protection, player_index)
    if effects.size() > 0:
        var effect = effects[0]
        _hit_protection += int(Utils.get_stat(effect[0], player_index) / effect[1])
        _max_hit_protection = _hit_protection
    
    # 配置防护回复
    effects = RunData.get_player_effect(effect_fengliu_regen_hit_protection, player_index)
    if effects.size() > 0:
        _regen_hit_protection_timer = FixedTimer.new(effects[0][2])
        _regen_hit_protection = effects[0]

    # 配置静止爆炸
    effects = RunData.get_player_effect(effect_fengliu_not_moving_explosion, player_index)
    if effects.size() > 0:
        _not_moving_explosion_timer = FixedTimer.new(effects[0].wait_time)
        _clean_up_room_timer = FixedTimer.new(1)
        _can_not_moving_explosio = false
        _exploding_on_clean_up_room = effects[0].exploding_on_clean_up_room


# 获取玩家 UI
func fengliu_get_player_ui() -> PlayerUIElements:
    # 缓存玩家UI
    if _player_ui == null:
        var main = get_node("/root/Main")
        _player_ui = main._players_ui[player_index]
    
    return _player_ui


# 扩展每帧防护与爆炸计时
func _physics_process(delta: float) -> void :
    # 防护回复计时
    if _regen_hit_protection_timer != null and _regen_hit_protection_timer.try_loop(delta) > 0:
        fengliu_on_regen_hit_protection()

    # 静止爆炸计时
    if _not_moving_explosion_timer != null and _not_moving_explosion_timer.try_loop(delta) > 0:
        fengliu_on_moving_explosion_timeout()

    # 清理房间计时
    if _clean_up_room_timer != null and _clean_up_room_timer.try_loop(delta) > 0:
        fengliu_on_clean_up_room()
    

# 扩展受伤防护
func take_damage(value: int, args: TakeDamageArgs) -> Array:
    # 受伤启动防护回复并加临时属性
    if _regen_hit_protection_timer != null and (_invincibility_timer.is_stopped() or args.bypass_invincibility):
        if _regen_hit_protection_timer.is_stopped():
            _regen_hit_protection_timer.start()

        for effect in RunData.get_player_effect(effect_fengliu_temp_stats_on_hit_protection, player_index):
            TempStats.add_stat(effect[0], effect[1], player_index)

    return .take_damage(value, args)


# 回复防护值
func fengliu_on_regen_hit_protection() -> void:
    # 已达上限则停止
    if _hit_protection >= _max_hit_protection:
        _regen_hit_protection_timer.stop()
        return
    
    var stat_count = Utils.get_stat(_regen_hit_protection[0], player_index)
    # 按概率回复
    if not Utils.get_chance_success(fengliu_get_dynamic_chance(_regen_hit_protection[1], _regen_hit_protection[3], stat_count)):
        return

    # 回复并刷新UI
    _hit_protection += 1
    if fengliu_get_player_ui() != null:
        fengliu_get_player_ui().update_hit_protection_count(self, _hit_protection)


# 放大玩家体型
func fengliu_set_scale_size(gain: float) -> void:
    # 按比例放大
    _scale_value += _scale_value * (gain / 100.0)
    # 上限 5
    if _scale_value > 5:
        _scale_value = 5

    scale = Vector2(_scale_value, _scale_value)


# 扩展拾取消耗品结算
func on_consumable_picked_up(consumable_data: ConsumableData) -> void :
    # 拾取消耗品加属性
    var effects = RunData.get_player_effect(effect_fengliu_consumable_stats, player_index)
    if effects.size() > 0:
        for effect in effects:
            RunData.add_stat(effect[0], effect[1], player_index)

    # 开箱加属性
    effects = RunData.get_player_effect(effect_fengliu_effect_box_stats, player_index)
    if effects.size() > 0 and (consumable_data.my_id_hash == Keys.consumable_item_box_hash 
            or consumable_data.my_id_hash == Keys.consumable_legendary_item_box_hash):
        for effect in effects:
            RunData.add_stat(effect[0], effect[1], player_index)

    # 拾取加体型
    effects = RunData.get_player_effect(effect_fengliu_picked_up_consumable_add_size, player_index)
    if effects.size() > 0: 
        fengliu_set_scale_size(effects[0][0])

    .on_consumable_picked_up(consumable_data)


# 清理房间时处理爆炸
func fengliu_on_clean_up_room():
    # 停止爆炸计时
    if not _not_moving_explosion_timer.is_stopped():
        _not_moving_explosion_timer.stop()
    
    if not _clean_up_room_timer.is_stopped():
        _clean_up_room_timer.stop()
    
    var main = Utils.get_scene_node()
    # 无精英则正常清理
    if main._entity_spawner.get_nb_bosses_and_elites_alive() == 0:
        main.clean_up_room()
    # 有精英则扣血取消清理
    elif RunData.get_player_effect(effect_fengliu_can_one_not_moving_explosion, player_index).size() > 0:
        if not main._end_wave_timer.is_stopped():
            main._end_wave_timer.stop()
        main._cleaning_up = false
        _take_damage_args.dodgeable = false
        _take_damage_args.armor_applied = false
        _take_damage_args.bypass_invincibility = true
        _take_damage_args.from = self
        var _dmg_taken = take_damage(int(Utils.get_stat(Keys.stat_max_hp_hash, player_index)), _take_damage_args)

# 静止爆炸计时触发爆炸
func fengliu_on_moving_explosion_timeout():
    var effects = RunData.get_player_effect(effect_fengliu_not_moving_explosion, player_index)
    # 触发爆炸
    if effects.size() > 0 and not effects[0] is int:
        RunData.handle_explode_effect(effects[0].key_hash, global_position, player_index)

    # 清理时爆炸则启动清理计时
    if _exploding_on_clean_up_room:
        _clean_up_room_timer.start()


# 扩展静止检测
func check_not_moving_stats(movement: Vector2) -> void :
    if dead:
        return

    .check_not_moving_stats(movement) 
    # 静止且满足条件则启动爆炸计时
    if not (movement.x == 0 and movement.y == 0) or _not_moving_explosion_timer == null or not _can_not_moving_explosio:
        return
    
    if _not_moving_explosion_timer.is_stopped():
        _not_moving_explosion_timer.start()


# 扩展移动检测
func check_moving_stats(movement: Vector2) -> void :
    if dead:
        return

    .check_moving_stats(movement)
    # 移动时记录静止标志
    if not (movement.x != 0 or movement.y != 0) or _not_moving_explosion_timer == null:
        return

    _can_not_moving_explosio = true
    if not _not_moving_explosion_timer.is_stopped():
        _not_moving_explosion_timer.stop()