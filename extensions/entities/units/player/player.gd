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
var effect_fengliu_full_shield_stat_link: int = Keys.generate_hash("fengliu_full_shield_stat_link")
var effect_fengliu_shield_to_hit_protection_front = Keys.generate_hash("fengliu_shield_to_hit_protection_front")
var effect_fengliu_shield_set_hit_protection = Keys.generate_hash("fengliu_shield_set_hit_protection")
var effect_fengliu_shield_not_regen = Keys.generate_hash("fengliu_shield_not_regen")
var effect_fengliu_shield_hp_together = Keys.generate_hash("fengliu_shield_hp_together")
var effect_fengliu_random_primary_stats_on_shield_broken = Keys.generate_hash("fengliu_random_primary_stats_on_shield_broken")


var fengliu_shield_hash: int = Keys.generate_hash("stat_fengliu_shield")
var fengliu_reduce_shield_damage_hash = Keys.generate_hash("fengliu_reduce_shield_damage")
var fengliu_consumable_shield_regen_hash = Keys.generate_hash("fengliu_consumable_shield_regen")
var fengliu_hit_shield_drop_consumable_hash = Keys.generate_hash("fengliu_hit_shield_drop_consumable")


var fengliu_item_plastic_fruit_basket_hash = Keys.generate_hash("item_plastic_fruit_basket")
var fengliu_item_plastic_candy_jar_hash = Keys.generate_hash("item_plastic_candy_jar")


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
var fengliu_shield_regen_delay: float = 3.0
var fengliu_shield_regen_tick: float = 1.0
var fengliu_shield_regen_rate: float = 0.1

var _fengliu_shield_regen_timer: = FixedTimer.new(3.0)
var _fengliu_shield_regen_pool: float = 0.0
var _fengliu_shield_reduce_pool: float = 0.0
var _fengliu_no_hit_material_effects: Array = []
var _fengliu_no_hit_material_timers: Array = []
var _fengliu_no_hit_material_disabled: Array = []
var _fengliu_full_shield_link_active: bool = false
var _fengliu_full_shield_link_effects: Array = []


# 盾恢复信号
signal fengliu_shield_gained(value, player_index)
# 盾扣减信号
signal fengliu_shield_lost(value, player_index)


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
    
    # 配置盾值
    fengliu_shield = Utils.get_stat(fengliu_shield_hash, player_index)

    # 配置未受伤奖励材料（逐实例计时器）
    fengliu_sync_no_hit_material_timers()

    # 配置满盾联动（初始盾值即按满/不满判定）
    fengliu_sync_full_shield_stat_link()


# 生成一个消耗品模拟树
func _fengliu_drop_consumable() -> void:
    var main = get_tree().current_scene

    var old_stats = stats
    var tree_stats = stats.duplicate()
    tree_stats.can_drop_consumables = true
    tree_stats.base_drop_chance = 1.0
    tree_stats.item_drop_chance = 0.2
    tree_stats.min_consumable_tier = Tier.COMMON
    tree_stats.max_consumable_tier = Tier.COMMON
    stats = tree_stats

    main.spawn_consumables(self)
    stats = old_stats


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

    # 盾优先吃这次伤害
    if fengliu_can_shield_take_damage(value, args):
        var previous_armor_applied: bool = args.armor_applied
        var incoming_damage: int = value
        var shield_broken: bool = false
        var reduce_shield_damage = RunData.get_player_effect(fengliu_reduce_shield_damage_hash, player_index)

        if reduce_shield_damage < 0:
            reduce_shield_damage = 0

        # 抵消型护盾 每次受击固定消耗的护盾点数
        var effect = RunData.get_player_effect(effect_fengliu_shield_set_hit_protection, player_index)
        var shield_hit_protection_damage: int = 0
        if effect is int:
            shield_hit_protection_damage = effect

        effect = RunData.get_player_effect(effect_fengliu_shield_hp_together, player_index)
        var shield_hp_together = false
        if effect is int and effect > 0:
            shield_hp_together = true

        if shield_hp_together:
            incoming_damage = incoming_damage / 2

        var reduce = abs(100 - reduce_shield_damage) / 100.0
        var shield_before: float = fengliu_shield
        var pool_before: float = _fengliu_shield_reduce_pool
        
        var shield_spent: float = incoming_damage * reduce + _fengliu_shield_reduce_pool
        if shield_hit_protection_damage > 0 and shield_before >= shield_hit_protection_damage:
            shield_spent = shield_hit_protection_damage

        var shield_spent_int: int = int(floor(shield_spent))
        _fengliu_shield_reduce_pool = shield_spent - shield_spent_int

        var shield_lost: int = _fengliu_take_shield(shield_spent_int)
        if fengliu_shield > 0:
            # 全吸收
            value = 0
            args.armor_applied = false
        else:
            # 打穿
            var absorbed_damage: int = int(round(max(0.0, shield_before - pool_before) / reduce))
            if shield_before >= shield_hit_protection_damage and shield_hit_protection_damage > 0:
                value = 0
            else:
                value = incoming_damage - absorbed_damage
                shield_broken = true

        if shield_hp_together:
            value += incoming_damage
            args.armor_applied = true

        # 非正伤害不结算
        if value <= 0:
            value = 0
            args.armor_applied = false

        # 盾全吸收时临时清空抵消次数
        var shield_full_absorb: bool = value <= 0
        var hit_protection_before: int = _hit_protection
        if shield_full_absorb:
            _hit_protection = 0

        var damage_taken = .take_damage(value, args)
        if shield_full_absorb:
            _hit_protection = hit_protection_before

        args.armor_applied = previous_armor_applied
        # 被闪避的伤害不吃盾：退还（静默，不飘 -x）
        if damage_taken.size() > 2 and damage_taken[2]:
            fengliu_shield = min(fengliu_shield + shield_lost, Utils.get_stat(fengliu_shield_hash, player_index))
            _fengliu_shield_reduce_pool = pool_before
        else:
            if shield_lost > 0:
                emit_signal("fengliu_shield_lost", shield_lost, player_index)
                
            # 受击后重新开始回盾静默计时
            fengliu_restart_shield_regen_delay(shield_lost, damage_taken)
            # 破盾触发：材料计时失效（+ 破盾爆炸，不含自伤）
            if shield_broken:
                fengliu_on_shield_broken(args.from != self)

        fengliu_sync_full_shield_stat_link()

        # 掉血
        if damage_taken.size() > 1 and damage_taken[1] > 0:
            fengliu_on_hit_dmg()

        return damage_taken

    var damage_taken_without_shield = .take_damage(value, args)
    fengliu_restart_shield_regen_delay(0, damage_taken_without_shield)
    # 掉血
    if damage_taken_without_shield.size() > 1 and damage_taken_without_shield[1] > 0:
        fengliu_on_hit_dmg()
    return damage_taken_without_shield


# 扣盾
func fengliu_deduct_shield(amount: int) -> int:
    var lost: int = _fengliu_take_shield(amount)
    if lost > 0:
        emit_signal("fengliu_shield_lost", lost, player_index)
        fengliu_sync_full_shield_stat_link()

    return lost


func fengliu_hit_shield_drop_consumable() -> void:
    var hit_shield_drop_consumable = RunData.get_player_effect(fengliu_hit_shield_drop_consumable_hash, player_index) / 100.0
    if hit_shield_drop_consumable <= 0:
        return

    var hit_shield_drop_consumable_count = int(hit_shield_drop_consumable)
    var hit_shield_drop_consumable_chance = hit_shield_drop_consumable - hit_shield_drop_consumable_count

    # 必掉份数 + 小数概率补一份
    for _i in hit_shield_drop_consumable_count:
        _fengliu_drop_consumable()
        RunData.add_tracked_value(player_index, fengliu_item_plastic_fruit_basket_hash, 1)
        
    if Utils.get_chance_success(hit_shield_drop_consumable_chance):
        _fengliu_drop_consumable()
        RunData.add_tracked_value(player_index, fengliu_item_plastic_fruit_basket_hash, 1)


# 盾值扣减
func _fengliu_take_shield(amount: int) -> int:
    if amount <= 0 or dead or fengliu_shield <= 0:
        return 0

    var shield_before: float = fengliu_shield
    fengliu_shield = max(0.0, shield_before - amount)
    var lost: int = int(round(shield_before)) - int(round(fengliu_shield))

    if lost <= 0:
        return 0

    # 打穿时零头池一并结算
    if fengliu_shield <= 0.0:
        _fengliu_shield_reduce_pool = 0.0

    fengliu_hit_shield_drop_consumable()
    return lost


func fengliu_hit_lost_item() -> void:
    for player_item in RunData.get_player_items(player_index):
        if player_item.get("is_hit_lost_item") != true:
            continue

        RunData.remove_item(player_item, player_index)


func fengliu_on_hit_dmg() -> void:
    fengliu_hit_lost_item()
    fengliu_no_hit_material()


# 破盾触发
func fengliu_on_shield_broken(can_explode: bool = true) -> void:
    for effect in RunData.get_player_effect(effect_fengliu_random_primary_stats_on_shield_broken, player_index):
        for _i in effect[0]:
            RunData.add_stat(RunData.get_random_primary_stats(), 1, player_index)
            RunData.add_tracked_value(player_index, fengliu_item_plastic_candy_jar_hash, 1)
            
    if not can_explode or RunData.get_player_effect(effect_fengliu_explode_on_shield_broken, player_index).size() == 0:
        return

    RunData.handle_explode_effect(effect_fengliu_explode_on_shield_broken, global_position, player_index)


# 盾能否吃下这次伤害
func fengliu_can_shield_take_damage(value: int, args: TakeDamageArgs) -> bool:
    if value <= 0 or dead or fengliu_shield <= 0:
        return false

    if _hit_protection != 0:
        var effect = RunData.get_player_effect(effect_fengliu_shield_to_hit_protection_front, player_index)
        if not effect is int:
            return false
            
        return effect > 0

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


# 满盾联动：护盾满时挂上「每 N 点属性加 M 点属性」，不满时摘下
func fengliu_sync_full_shield_stat_link() -> void:
    var shield_cap: float = Utils.get_stat(fengliu_shield_hash, player_index)
    var is_full: bool = shield_cap > 0.0 and fengliu_shield >= shield_cap
    var effects: Array = RunData.get_player_effect(effect_fengliu_full_shield_stat_link, player_index)

    # 轻量守卫：满盾状态与槽内容都没变就什么都不做（每帧只花这两行）
    if is_full == _fengliu_full_shield_link_active and effects == _fengliu_full_shield_link_effects:
        return

    # 期望条数：满盾时 = 同签名实例数；不满盾 = 0
    var wanted := {}
    for effect in effects:
        # value 为 0 会除零，不参与联动
        if effect.value <= 0:
            continue
        var effect_sig: String = fengliu_stat_link_signature(effect)
        wanted[effect_sig] = wanted.get(effect_sig, 0) + 1
    if not is_full:
        for effect_sig in wanted:
            wanted[effect_sig] = 0

    # 关心集合 = 槽内签名 ∪ 上一次挂过的签名（道具被移除时靠它收尾）
    var sigs := {}
    for effect_sig in wanted:
        sigs[effect_sig] = true
    for old_effect in _fengliu_full_shield_link_effects:
        if old_effect.value > 0:
            sigs[fengliu_stat_link_signature(old_effect)] = true

    var player_effects: Dictionary = RunData.get_player_effects(player_index)
    # 原版联动表可能尚未建立，先补空
    if not player_effects.has(Keys.stat_links_hash):
        player_effects[Keys.stat_links_hash] = []
    var stat_links: Array = player_effects[Keys.stat_links_hash]

    # 多退少补（仅在翻转或槽变化时执行）
    var changed: bool = false
    for effect_sig in sigs:
        var wanted_nb: int = wanted.get(effect_sig, 0)
        while fengliu_count_stat_link_signature(stat_links, effect_sig) > wanted_nb:
            fengliu_erase_stat_link_signature(stat_links, effect_sig)
            changed = true
        while fengliu_count_stat_link_signature(stat_links, effect_sig) < wanted_nb:
            stat_links.push_back(fengliu_find_stat_link_tuple(effects, effect_sig))
            changed = true

    _fengliu_full_shield_link_active = is_full
    _fengliu_full_shield_link_effects = effects.duplicate()

    # 联动增删后必须触发 LinkedStats 重算：只清缓存不会重算
    if changed:
        LinkedStats.reset_player(player_index)
        Utils.reset_stat_cache(player_index)

# 效果实例对应的联动签名（数值化，兼容读档后的浮点）
func fengliu_stat_link_signature(effect) -> String:
    return fengliu_stat_link_signature_of(int(effect.key_hash), int(effect.value), int(effect.stat_scaled_hash), int(effect.nb_stat_scaled))


# 联动条目对应的签名
func fengliu_tuple_signature(tuple: Array) -> String:
    if tuple.size() < 4:
        return ""
    return fengliu_stat_link_signature_of(int(tuple[0]), int(tuple[1]), int(tuple[2]), int(tuple[3]))


# 签名文本：四项都用数值，读档回来的浮点也能对上
func fengliu_stat_link_signature_of(key_hash: int, value: int, stat_scaled_hash: int, nb_stat_scaled: int) -> String:
    return str(key_hash) + ":" + str(value) + ":" + str(stat_scaled_hash) + ":" + str(nb_stat_scaled)


func fengliu_count_stat_link_signature(stat_links: Array, sig: String) -> int:
    var count: int = 0
    for link in stat_links:
        if link is Array and fengliu_tuple_signature(link) == sig:
            count += 1
    return count


# 摘掉联动表里第一条该签名的条目
func fengliu_erase_stat_link_signature(stat_links: Array, sig: String) -> void:
    for i in range(stat_links.size() - 1, -1, -1):
        if fengliu_tuple_signature(stat_links[i]) == sig:
            stat_links.remove(i)
            return


# 找一个该签名的槽内实例并生成联动条目
func fengliu_find_stat_link_tuple(slot_effects: Array, sig: String) -> Array:
    for effect in slot_effects:
        if effect.value > 0 and fengliu_stat_link_signature(effect) == sig:
            return [effect.key_hash, effect.value, effect.stat_scaled_hash, effect.nb_stat_scaled, effect.perm_stats_only]
    return []


# 盾恢复
func fengliu_shield_regen(regen: int) -> int:
    var effect = RunData.get_player_effect(effect_fengliu_shield_not_regen, player_index)
    if effect is int and effect > 0:
        return 0

    if regen <= 0:
        return 0
    
    var max_shield: float = Utils.get_stat(fengliu_shield_hash, player_index)
    if max_shield <= 0.0 or fengliu_shield >= max_shield:
        return 0

    var shield_before: float = fengliu_shield
    fengliu_shield = min(shield_before + regen, max_shield)
    var gained: int = int(round(fengliu_shield - shield_before))

    # +x 恢复显示
    if gained > 0:
        emit_signal("fengliu_shield_gained", gained, player_index)
    if fengliu_shield >= max_shield:
        if not _fengliu_shield_regen_timer.is_stopped():
            _fengliu_shield_regen_timer.stop()
            _fengliu_shield_regen_pool = 0.0
        
        fengliu_sync_full_shield_stat_link()

    return gained


# 回盾：每跳回盾上限的 10%（严格 10%/秒、零头累积），回满即停
func fengliu_on_shield_regen(loop_count: int) -> void:
    var max_shield: float = Utils.get_stat(fengliu_shield_hash, player_index)
    if dead or cleaning_up or max_shield <= 0.0 or fengliu_shield >= max_shield:
        _fengliu_shield_regen_timer.stop()
        _fengliu_shield_regen_pool = 0.0
        return

    _fengliu_shield_regen_pool += max_shield * fengliu_shield_regen_rate * loop_count
    if _fengliu_shield_regen_pool >= 1.0:
        var pool_gain: int = int(_fengliu_shield_regen_pool)
        _fengliu_shield_regen_pool -= pool_gain
        fengliu_shield_regen(pool_gain)

    # 3 秒静默后的首跳起，改为「1 秒 + 每 20 护盾上限 1 秒」一跳
    _fengliu_shield_regen_timer.wait_time = fengliu_shield_regen_tick
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
    fengliu_shield_regen(RunData.get_player_effect(fengliu_consumable_shield_regen_hash, player_index))

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
