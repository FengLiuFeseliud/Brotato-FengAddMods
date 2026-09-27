extends Player


var effect_fengliu_consumable_stats = Keys.generate_hash("fengliu_consumable_stats")
var effect_fengliu_effect_box_stats = Keys.generate_hash("fengliu_box_stats")
var effect_fengliu_effect_stat_hit_protection = Keys.generate_hash("fengliu_stat_hit_protection")
var effect_fengliu_regen_hit_protection = Keys.generate_hash("fengliu_regen_hit_protection")
var effect_fengliu_temp_stats_on_hit_protection = Keys.generate_hash("fengliu_temp_stats_on_hit_protection")
var effect_fengliu_not_moving_explosion = Keys.generate_hash("fengliu_not_moving_explosion")
var effect_fengliu_can_one_not_moving_explosion = Keys.generate_hash("fengliu_can_one_not_moving_explosion")
var effect_fengliu_picked_up_consumable_add_size = Keys.generate_hash("fengliu_picked_up_consumable_add_size")
var effect_fengliu_explode_on_shield_broken: int = Keys.generate_hash("fengliu_explode_on_shield_broken")
var effect_fengliu_no_hit_material: int = Keys.generate_hash("fengliu_no_hit_material")

var fengliu_shield_hash: int = Keys.generate_hash("stat_fengliu_shield")

var _max_hit_protection = 0
var _regen_hit_protection_timer = null
var _player_ui = null
var _regen_hit_protection = []
var _not_moving_explosion_timer
var _can_not_moving_explosio = false
var _clean_up_room_timer
var _exploding_on_clean_up_room
var _scale_value = 1 

var fengliu_shield = 0
var fengliu_shield_absorb: int = 0

var fengliu_shield_regen_delay: float = 3.0
var fengliu_shield_regen_tick: float = 1.0
var fengliu_shield_regen_rate: float = 0.1
var fengliu_shield_regen_shield_per_step: float = 20.0
var fengliu_shield_regen_tick_per_step: float = 1.0

var _fengliu_shield_regen_timer: = FixedTimer.new(3.0)
var _fengliu_shield_regen_pool: float = 0.0
var _fengliu_no_hit_material_effects: Array = []
var _fengliu_no_hit_material_timers: Array = []
var _fengliu_no_hit_material_disabled: Array = []


# 计算动态概率
static func fengliu_get_dynamic_chance(init_chance: int, add_chance: int = 0, stat_count: int = 0) -> float:
	# 基础概率 + 属性数 * 每点加成
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	# 上限 100
	if dynamic_chance > 100:
		return 100.0 / 100
		
	return dynamic_chance / 100


# 计算回盾间隔：基础 1 秒 + 每 20 点护盾上限加 1 秒（上限不足 20 或为负时按 0 步计）
static func fengliu_get_shield_regen_tick(base_tick: float, max_shield: float, shield_per_step: float, tick_per_step: float) -> float:
    var steps = int(floor(max_shield / shield_per_step))
    # 上限为负时本项不生效，避免间隔被压到 0（FixedTimer 会除零放大 loop_count）
    if steps < 0:
        steps = 0

    return base_tick + (steps * tick_per_step)


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
    
    # 配置盾值
    fengliu_shield = Utils.get_stat(fengliu_shield_hash, player_index)

    # 配置未受伤奖励材料（逐实例计时器）
    fengliu_sync_no_hit_material_timers()


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

    # 回盾计时：满 3 秒静默后开始，之后每「1 秒 + 每 20 护盾上限 1 秒」一跳
    var shield_regen_loop: int = _fengliu_shield_regen_timer.try_loop(delta)
    if shield_regen_loop > 0:
        fengliu_on_shield_regen(shield_regen_loop)

    # 未受伤计时：每个效果实例各自计时，满一轮结算一次材料（先同步槽位变化）
    fengliu_sync_no_hit_material_timers()
    for i in _fengliu_no_hit_material_timers.size():
        # 受伤后本波失效的实例不再计时
        if i < _fengliu_no_hit_material_disabled.size() and _fengliu_no_hit_material_disabled[i]:
            continue
        var no_hit_material_loop: int = _fengliu_no_hit_material_timers[i].try_loop(delta)
        if no_hit_material_loop > 0:
            fengliu_on_no_hit_material(_fengliu_no_hit_material_effects[i], no_hit_material_loop)
    

# 扩展受伤防护
func take_damage(value: int, args: TakeDamageArgs) -> Array:
    # 受伤启动防护回复并加临时属性
    if _regen_hit_protection_timer != null and (_invincibility_timer.is_stopped() or args.bypass_invincibility):
        if _regen_hit_protection_timer.is_stopped():
            _regen_hit_protection_timer.start()

        for effect in RunData.get_player_effect(effect_fengliu_temp_stats_on_hit_protection, player_index):
            TempStats.add_stat(effect[0], effect[1], player_index)

    fengliu_shield_absorb = 0

    # 盾优先吃这次伤害
    if fengliu_can_shield_take_damage(value, args):
        var previous_armor_applied: bool = args.armor_applied
        var incoming_damage: int = value
        var shield_broken: bool = false

        fengliu_shield -= value
        if fengliu_shield > 0:
            # 全吸收
            value = 0
            args.armor_applied = false
        else:
            # 打穿
            value = int(abs(fengliu_shield))
            fengliu_shield = 0
            shield_broken = true

        var shield_absorbed: int = incoming_damage - value
        fengliu_shield_absorb = shield_absorbed

        var damage_taken = .take_damage(value, args)
        args.armor_applied = previous_armor_applied

        # 被闪避的伤害不吃盾
        if damage_taken.size() > 2 and damage_taken[2]:
            fengliu_shield = min(fengliu_shield + shield_absorbed, Utils.get_stat(fengliu_shield_hash, player_index))
        else:
            # 受击后重新开始回盾静默计时
            fengliu_restart_shield_regen_delay(shield_absorbed, damage_taken)
            # 破盾触发：材料计时失效（+ 破盾爆炸，不含自伤）
            if shield_broken:
                fengliu_on_shield_broken(args.from != self)

        return damage_taken

    var damage_taken_without_shield = .take_damage(value, args)
    fengliu_restart_shield_regen_delay(0, damage_taken_without_shield)
    return damage_taken_without_shield


func fengliu_consume_shield_absorb() -> int:
    var count = fengliu_shield_absorb
    fengliu_shield_absorb = 0
    return count


# 破盾触发：材料计时失效 + 破盾爆炸（爆炸仅在非自伤时触发）
func fengliu_on_shield_broken(can_explode: bool = true) -> void:
    fengliu_no_hit_material()

    if not can_explode or RunData.get_player_effect(effect_fengliu_explode_on_shield_broken, player_index).size() == 0:
        return

    RunData.handle_explode_effect(effect_fengliu_explode_on_shield_broken, global_position, player_index)


# 盾能否吃下这次伤害
func fengliu_can_shield_take_damage(value: int, args: TakeDamageArgs) -> bool:
    if value <= 0 or dead or fengliu_shield <= 0:
        return false

    if _hit_protection != 0:
        return false

    if args.hitbox != null and args.hitbox.is_healing:
        return false

    if not _invincibility_timer.is_stopped() and not args.bypass_invincibility:
        return false

    return true


# 受击后重新开始回盾静默计时
func fengliu_restart_shield_regen_delay(shield_absorbed: int, damage_taken: Array) -> void:
    if not (shield_absorbed > 0 or (damage_taken.size() > 1 and damage_taken[1] > 0)):
        return

    _fengliu_shield_regen_pool = 0.0
    _fengliu_shield_regen_timer.wait_time = fengliu_shield_regen_delay
    _fengliu_shield_regen_timer.start()


# 材料计时开了 disable_on_hit 的实例本波失效，其余重新计时
func fengliu_no_hit_material() -> void:
    for i in _fengliu_no_hit_material_timers.size():
        if i < _fengliu_no_hit_material_effects.size() and _fengliu_no_hit_material_effects[i].disable_on_hit:
            if i < _fengliu_no_hit_material_disabled.size():
                _fengliu_no_hit_material_disabled[i] = true
            _fengliu_no_hit_material_timers[i].stop()
            continue
        _fengliu_no_hit_material_timers[i].start()


# 回盾：每跳回盾上限的 10%（严格 10%/秒、零头累积），回满即停
func fengliu_on_shield_regen(loop_count: int) -> void:
    var max_shield: float = Utils.get_stat(fengliu_shield_hash, player_index)
    if dead or cleaning_up or max_shield <= 0.0 or fengliu_shield >= max_shield:
        _fengliu_shield_regen_timer.stop()
        _fengliu_shield_regen_pool = 0.0
        return

    _fengliu_shield_regen_pool += max_shield * fengliu_shield_regen_rate * loop_count
    if _fengliu_shield_regen_pool >= 1.0:
        fengliu_shield = min(fengliu_shield + int(_fengliu_shield_regen_pool), max_shield)
        _fengliu_shield_regen_pool -= int(_fengliu_shield_regen_pool)

    if fengliu_shield >= max_shield:
        _fengliu_shield_regen_timer.stop()
        _fengliu_shield_regen_pool = 0.0
        return

    # 3 秒静默后的首跳起，改为「1 秒 + 每 20 护盾上限 1 秒」一跳
    _fengliu_shield_regen_timer.wait_time = fengliu_get_shield_regen_tick(fengliu_shield_regen_tick, max_shield, fengliu_shield_regen_shield_per_step, fengliu_shield_regen_tick_per_step)
    _fengliu_shield_regen_timer.start()


# 同步「未受伤奖励材料」的逐实例计时器：新增补一个、移除的丢弃、已存在的保留进度
func fengliu_sync_no_hit_material_timers() -> void:
    var effects = RunData.get_player_effect(effect_fengliu_no_hit_material, player_index)

    # 槽内容与缓存一致时直接返回，避免每帧重建
    if effects.size() == _fengliu_no_hit_material_effects.size():
        var unchanged := true
        for i in effects.size():
            if effects[i] != _fengliu_no_hit_material_effects[i]:
                unchanged = false
                break
        if unchanged:
            return

    var new_effects := []
    var new_timers := []
    var new_disabled := []
    # 记录已占用的旧索引：同一实例被压下两次时也能各自配对到一个计时器
    var used_indexs := {}
    for effect in effects:
        var matched_index := -1
        for i in _fengliu_no_hit_material_effects.size():
            if used_indexs.has(i) or _fengliu_no_hit_material_effects[i] != effect:
                continue
            matched_index = i
            break

        var wait_time: float = max(0.1, float(effect.wait_time))
        # 已存在的实例沿用原计时器（保留进度），只有间隔变了才重设
        if matched_index >= 0:
            used_indexs[matched_index] = true
            var kept_timer = _fengliu_no_hit_material_timers[matched_index]
            if kept_timer.wait_time != wait_time:
                kept_timer.wait_time = wait_time
                kept_timer.start()
            new_effects.push_back(effect)
            new_timers.push_back(kept_timer)
            new_disabled.push_back(_fengliu_no_hit_material_disabled[matched_index])
            continue

        # 新实例补一个计时器
        var new_timer := FixedTimer.new(wait_time)
        new_timer.start()
        new_effects.push_back(effect)
        new_timers.push_back(new_timer)
        new_disabled.push_back(false)

    _fengliu_no_hit_material_effects = new_effects
    _fengliu_no_hit_material_timers = new_timers
    _fengliu_no_hit_material_disabled = new_disabled


# 未受伤满一轮：按该效果实例的值加材料，并按追踪键累计
func fengliu_on_no_hit_material(effect, loop_count: int) -> void:
    # 死亡或清理房间时不结算
    if dead or cleaning_up:
        return

    var gained: int = int(effect.value) * loop_count
    if gained <= 0:
        return

    RunData.add_gold(gained, player_index)

    # 有追踪键时累计到道具追踪（填道具 id，同 key 的多个实例汇总到同一条）
    var tracking_key: String = effect.tracking_key
    if tracking_key != "":
        RunData.add_tracked_value(player_index, Keys.generate_hash(tracking_key), gained)


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
    for effect in RunData.get_player_effect(effect_fengliu_consumable_stats, player_index):
        if not Utils.get_chance_success(effect[1] / 100.0):
            continue
        
        if Utils.is_stat_key(effect[0]):
            RunData.add_stat(effect[0], effect[2], player_index)
        else:
            RunData.get_player_effects(player_index)[effect[0]] += effect[2]

    # 拾取加体型
    for effect in RunData.get_player_effect(effect_fengliu_picked_up_consumable_add_size, player_index):
        fengliu_set_scale_size(effect[0])

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
