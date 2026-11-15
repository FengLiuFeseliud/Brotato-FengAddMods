extends "res://entities/units/enemies/enemy.gd"


var effect_fengliu_wave_intensity_damage = Keys.generate_hash("fengliu_wave_intensity_damage")
var effect_fengliu_no_kill_enemy = Keys.generate_hash("fengliu_no_kill_enemy")
var effect_fengliu_charm_enemy = Keys.generate_hash("fengliu_charm_enemy")
var effect_fengliu_weapon_charm_enemy = Keys.generate_hash("fengliu_weapon_charm_enemy")
var effect_fengliu_stronger_aliens_on_stats = Keys.generate_hash("fengliu_stronger_aliens_on_stats")
var effect_fengliu_killed_regen_shield = Keys.generate_hash("fengliu_killed_regen_shield")


var _fengliu_charm_behavior_scene: PackedScene = null
var _fengliu_charm_behavior_scene_resolved := false


# 判断攻击来源是否匹配指定类型
func fengliu_key_in_class(key: String, hitbox: Hitbox = null) -> bool:
    # 无攻击来源则不匹配
    if hitbox == null or hitbox.from == null:
        return false

    # 构造物类型用类型判断
    if key == "Structure" and not hitbox.from is Structure:
        return false

    # 其它类型用类名判断
    if key != "Structure" and not hitbox.from.is_class(key):
        return false

    return true


# 判断本次伤害是否会被不致死效果拦截
func fengliu_no_kill_enemy(damage_value: GetDamageValueResult, effect: Array, hitbox: Hitbox = null) -> bool:
    # 非指定类型攻击则不拦截
    if not fengliu_key_in_class(effect[0], hitbox):
        return false

    # 伤害不足以致死则不拦截
    if damage_value.value < current_stats.health:
        return false
    
    return true


# 处理魅惑效果
func fengliu_charm_enemy(effect: Array, args: TakeDamageArgs) -> void:
    # 非指定类型攻击则不处理
    if not fengliu_key_in_class(effect[0], args.hitbox):
        return

    if is_loot or not can_be_charmed:
        return

    var chance
    var health = 1
    # 普通敌人按概率魅惑
    if not ("is_elite" in self):
        chance = effect[1] / 100.0
    else:
        # 未开启 boss 魅惑则跳过
        if not effect[2]:
            return

        # 精英/Boss 按生命值阈值魅惑
        health = max_stats.health * (effect[3] / 100.0)
        if health < 1:
            health = 1
            
        chance = 0.0

    # 概率未命中且生命值高于阈值则跳过
    if not Utils.get_chance_success(chance) and current_stats.health > health:
        return
    
    # 应用魅惑
    fengliu_apply_charm(args.from_player_index)


# 挂上魅惑行为并魅惑本敌人
func fengliu_apply_charm(from_player_index: int) -> void:
    # 检查是否已有魅惑行为
    var has_charm_behavior = false
    for effect_behavior in effect_behaviors.get_children():
        if "charmed" in effect_behavior:
            has_charm_behavior = true
            break

    if not has_charm_behavior:
        var charm_scene = fengliu_get_charm_behavior_scene()
        if charm_scene != null:
            # 与原版 init_effect_behaviors() 一致：先 init(self) 再挂到 effect_behaviors
            var charm_behavior = charm_scene.instance().init(self)
            effect_behaviors.add_child(charm_behavior)

    # 应用魅惑
    set_charmed(from_player_index)


# 武器命中魅惑（效果挂载在武器 effects 上，参考原版长笛）：
#   敌人当前生命低于 hp_threshold% 时，按 value + 属性 × gain_value/100 的概率魅惑
func fengliu_weapon_charm_enemy(hitbox: Hitbox = null) -> void:
    # 无攻击来源则不处理
    if hitbox == null or not is_instance_valid(hitbox.from):
        return

    # 敌人（含被魅惑的宠物）造成的伤害不触发
    var from = hitbox.from
    if from is Enemy:
        return

    var from_player_index = from.get("player_index")
    if not (from_player_index is int) or from_player_index < 0:
        return

    # 掉落物 / 不可魅惑 / 已死亡 / 已魅惑 / 精英或 Boss 均跳过（同长笛）
    if is_loot or not can_be_charmed or dead or _pending_die or _is_charmed:
        return
    if "is_elite" in self:
        return

    # 与原版魅惑行为一致：每个玩家同时最多魅惑 5 只
    if RunData.current_charmed_enemies[from_player_index] >= 5:
        return

    # 汇总武器效果的概率（多个来源可叠加）
    var charm_chance: float = fengliu_get_weapon_charm_chance(hitbox, from_player_index, current_stats.health, max_stats.health)
    if charm_chance <= 0.0:
        return

    # 与原版魅惑行为一致：无尽模式按 factor / 2 衰减
    charm_chance = charm_chance / max(1.0, RunData.get_endless_factor() / 2.0)
    if not Utils.get_chance_success(charm_chance):
        return

    fengliu_apply_charm(from_player_index)


# 汇总本次命中可触发的武器魅惑概率（0~1；不满足血线时不计入）
func fengliu_get_weapon_charm_chance(hitbox: Hitbox, from_player_index: int, health: int, max_health: int) -> float:
    var charm_chance: float = 0.0
    if hitbox == null or max_health <= 0:
        return charm_chance

    for effect in hitbox.effects:
        if effect == null or effect.custom_key_hash != effect_fengliu_weapon_charm_enemy:
            continue

        # 生命值阈值按当前（命中前）生命判定
        var hp_threshold = effect.get("hp_threshold")
        if hp_threshold == null:
            continue
        if float(health) / float(max_health) >= float(hp_threshold) / 100.0:
            continue

        # 概率 = 基础概率 + 缩放属性 × 倍率
        var chance: float = effect.value
        var gain_value = effect.get("gain_value")
        if effect.key_hash != Keys.empty_hash and gain_value != null:
            chance += Utils.get_stat(effect.key_hash, from_player_index) * (float(gain_value) / 100.0)
        charm_chance += chance / 100.0

    return charm_chance


func fengliu_get_charm_behavior_scene() -> PackedScene:
    if _fengliu_charm_behavior_scene_resolved:
        return _fengliu_charm_behavior_scene
    _fengliu_charm_behavior_scene_resolved = true

    if is_instance_valid(EffectBehaviorService):
        for behavior_data in EffectBehaviorService.enemy_effect_behaviors:
            if behavior_data == null or behavior_data.scene == null:
                continue
            var behavior_instance = behavior_data.scene.instance()
            if behavior_instance == null:
                continue
            var is_charm = "charmed" in behavior_instance
            behavior_instance.free()
            if is_charm:
                _fengliu_charm_behavior_scene = behavior_data.scene
                return _fengliu_charm_behavior_scene

    _fengliu_charm_behavior_scene = load("res://effect_behaviors/enemies/charm_enemy_effect_behavior.tscn")
    return _fengliu_charm_behavior_scene


# 扩展初始化：按波次强敌效果提高本敌人属性
func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
    .init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

    # 汇总所有玩家对该敌人的强敌加成
    var enemy_factor = 0
    for player_index in RunData.get_player_count():
        for effect in RunData.get_player_effect(effect_fengliu_stronger_aliens_on_stats, player_index):
            if effect[3] != enemy_id_hash:
                continue
            
            enemy_factor += effect[1] + int(Utils.get_stat(effect[0], player_index) * (effect[2] / 100.0))

    if enemy_factor > 0:
        reset_health_stat(enemy_factor)


# 击杀回盾量：汇总槽内全部实例的效果数值
func fengliu_get_killed_regen_shield_value(effects: Array) -> int:
    # 多份效果叠加；读档回来可能是浮点，统一取整
    var total: int = 0
    for effect in effects:
        total += int(effect[1])
    return total


# 扩展受击前置（与原版魅惑行为同一时点：伤害结算前）
func _on_hurt(hitbox: Hitbox) -> void:
    ._on_hurt(hitbox)
    fengliu_weapon_charm_enemy(hitbox)


# 扩展受伤结算
func take_damage(value: int, args: TakeDamageArgs) -> Array:
    var damage_taken = .take_damage(value, args)

    # 命中后触发魅惑
    var effects = RunData.get_player_effect(effect_fengliu_charm_enemy, args.from_player_index)
    if effects.size() > 0:
        fengliu_charm_enemy(effects[0], args)

    if args.from_player_index >= 0 and current_stats.health <= 0:
        # 击杀回盾量 = 槽内全部实例的效果数值之和；0 或负值不广播
        var regen = fengliu_get_killed_regen_shield_value(RunData.get_player_effect(effect_fengliu_killed_regen_shield, args.from_player_index))
        if regen > 0:
            RunData.emit_signal("fengliu_shield_regen", regen, args.from_player_index)

    return damage_taken



# 扩展伤害结算
func get_damage_value(dmg_value: int, from_player_index: int, armor_applied: = true, dodgeable: = true, is_crit: = false, hitbox: Hitbox = null, is_burning: = false) -> GetDamageValueResult:
    # 获取基础伤害
    var damage_value = .get_damage_value(dmg_value, from_player_index, armor_applied, dodgeable, is_crit, hitbox, is_burning)

    # 附加波次强度伤害（波次每秒总血量 × 百分比；槽位为总百分比）
    var wave_intensity_damage = RunData.get_player_effect(effect_fengliu_wave_intensity_damage, from_player_index)

    if wave_intensity_damage != 0:
        damage_value.value += int(RunData.fengliu_get_wave_total_hp_to_duration() * (wave_intensity_damage / 100.0))

    # 不致死效果：将伤害压到生命值剩余 1
    var effects = RunData.get_player_effect(effect_fengliu_no_kill_enemy, from_player_index)
    if effects.size() > 0 and fengliu_no_kill_enemy(damage_value, effects[0], hitbox):
        # 生命值已为 1 则不再造成伤害
        if current_stats.health <= 1:
            damage_value.value = 0
        else:
            # 伤害只降至生命值剩余 1
            damage_value.value = current_stats.health - 1
        return damage_value
    return damage_value
