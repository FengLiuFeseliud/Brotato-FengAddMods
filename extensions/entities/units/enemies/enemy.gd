extends Enemy


var effect_fengliu_wave_intensity_damage = Keys.generate_hash("fengliu_wave_intensity_damage")
var effect_fengliu_no_kill_enemy = Keys.generate_hash("fengliu_no_kill_enemy")
var effect_fengliu_charm_enemy = Keys.generate_hash("fengliu_charm_enemy")


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
    
    # 检查是否已有魅惑行为
    var has_charm_behavior = false
    for effect_behavior in effect_behaviors.get_children():
        if "charmed" in effect_behavior:
            has_charm_behavior = true
            break

    # 无魅惑行为则加载并添加
    if not has_charm_behavior:
        var charm_scene = load("res://dlcs/dlc_1/effect_behaviors/enemy/charm_enemy_effect_behavior.tscn")
        if charm_scene != null:
            var charm_behavior = charm_scene.instance()
            effect_behaviors.add_child(charm_behavior)
            charm_behavior.init(self)

    # 应用魅惑
    set_charmed(args.from_player_index)


# 扩展受伤结算
func take_damage(value: int, args: TakeDamageArgs) -> Array:
    var damage_taken = .take_damage(value, args)

    # 命中后触发魅惑
    var effects = RunData.get_player_effect(effect_fengliu_charm_enemy, args.from_player_index)
    if effects.size() > 0:
        fengliu_charm_enemy(effects[0], args)

    return damage_taken



# 扩展伤害结算
func get_damage_value(dmg_value: int, from_player_index: int, armor_applied: = true, dodgeable: = true, is_crit: = false, hitbox: Hitbox = null, is_burning: = false) -> GetDamageValueResult:
    # 获取基础伤害
    var damage_value = .get_damage_value(dmg_value, from_player_index, armor_applied, dodgeable, is_crit, hitbox, is_burning)

    # 附加波次强度伤害（波次每秒总血量 × 百分比）
    for effect in RunData.get_player_effect(effect_fengliu_wave_intensity_damage, from_player_index):
        damage_value.value += int(RunData.fengliu_get_wave_total_hp_to_duration() * (effect[0] / 100.0))

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