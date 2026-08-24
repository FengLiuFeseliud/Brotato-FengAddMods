extends Enemy


var effect_fengliu_wave_intensity_damage = Keys.generate_hash("fengliu_wave_intensity_damage")
var effect_fengliu_no_kill_enemy = Keys.generate_hash("fengliu_no_kill_enemy")
var effect_fengliu_charm_enemy = Keys.generate_hash("fengliu_charm_enemy")


func fengliu_key_in_class(key: String, hitbox: Hitbox = null) -> bool:
    if hitbox == null or hitbox.from == null:
        return false

    if key == "Structure" and not hitbox.from is Structure:
        return false

    if key != "Structure" and not hitbox.from.is_class(key):
        return false

    return true


func fengliu_no_kill_enemy(damage_value: GetDamageValueResult, effect: Array, hitbox: Hitbox = null) -> bool:
    if not fengliu_key_in_class(effect[0], hitbox):
        return false

    if damage_value.value < current_stats.health:
        return false
    
    return true



func fengliu_charm_enemy(effect: Array, args: TakeDamageArgs) -> void:
    if not fengliu_key_in_class(effect[0], args.hitbox):
        return

    var chance = effect[1] / 100.0
    if not Utils.get_chance_success(chance) and current_stats.health > 1:
        return
    
    var has_charm_behavior = false
    for effect_behavior in effect_behaviors.get_children():
        if "charmed" in effect_behavior:
            has_charm_behavior = true
            break

    if not has_charm_behavior:
        var charm_scene = load("res://dlcs/dlc_1/effect_behaviors/enemy/charm_enemy_effect_behavior.tscn")
        if charm_scene != null:
            var charm_behavior = charm_scene.instance()
            effect_behaviors.add_child(charm_behavior)
            charm_behavior.init(self)

    set_charmed(args.from_player_index)


func take_damage(value: int, args: TakeDamageArgs) -> Array:
    var damage_taken = .take_damage(value, args)

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

    var effects = RunData.get_player_effect(effect_fengliu_no_kill_enemy, from_player_index)
    if effects.size() > 0 and fengliu_no_kill_enemy(damage_value, effects[0], hitbox):
        if current_stats.health <= 1:
            damage_value.value = 0
        else:
            damage_value.value = current_stats.health - 1
        return damage_value
    return damage_value