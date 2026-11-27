extends "res://entities/units/enemies/enemy.gd"


var effect_fengliu_wave_intensity_damage = Keys.generate_hash("fengliu_wave_intensity_damage")
var effect_fengliu_no_kill_enemy = Keys.generate_hash("fengliu_no_kill_enemy")
var effect_fengliu_charm_enemy = Keys.generate_hash("fengliu_charm_enemy")
var effect_fengliu_weapon_charm_enemy = Keys.generate_hash("fengliu_weapon_charm_enemy")
var effect_fengliu_stronger_aliens_on_stats = Keys.generate_hash("fengliu_stronger_aliens_on_stats")
var effect_fengliu_killed_regen_shield = Keys.generate_hash("fengliu_killed_regen_shield")
var effect_fengliu_knockback_out_of_map = Keys.generate_hash("fengliu_knockback_out_of_map")
var fengliu_ignore_knockback_resistance_hash = Keys.generate_hash("fengliu_ignore_knockback_resistance")
var fengliu_freeze_chance_hash = Keys.generate_hash("fengliu_freeze_chance")
var effect_fengliu_weapon_wet = Keys.generate_hash("fengliu_weapon_wet")
var effect_fengliu_frozen_bonus_damage = Keys.generate_hash("fengliu_frozen_bonus_damage")


var _fengliu_charm_behavior_scene: PackedScene = null
var _fengliu_charm_behavior_scene_resolved := false


const FENGLIU_KNOCKBACK_DECAY_STEP := 0.1
const FENGLIU_KNOCK_OUT_DEATH_KNOCKBACK := 1.5
const FENGLIU_FREEZE_TINT := Color(0.55, 0.82, 1.0)
const FENGLIU_FREEZE_DURATION := 1.5
const FENGLIU_FREEZE_PARTICLES_SCENE = preload("res://mods-unpacked/FengLiu-FengAddMods/particles/freeze/unit_freeze_particles.tscn")
# 冰冻音效：复制自原版燃烧音（首次冻结 / 刷新 / 冰冻中受燃烧都播放）
const FENGLIU_FREEZE_SOUND_PATHS := [
    "res://mods-unpacked/FengLiu-FengAddMods/resources/sounds/freeze/freeze_01.wav",
    "res://mods-unpacked/FengLiu-FengAddMods/resources/sounds/freeze/freeze_02.wav",
    "res://mods-unpacked/FengLiu-FengAddMods/resources/sounds/freeze/freeze_03.wav",
    "res://mods-unpacked/FengLiu-FengAddMods/resources/sounds/freeze/freeze_04.wav",
]
const FENGLIU_FREEZE_SOUND_MIN_INTERVAL_MSEC := 150
# 潮湿（Wet）：武器命中必定施加，持续 N 秒，期间显示雨滴粒子
const FENGLIU_WET_DEFAULT_DURATION := 2.0
const FENGLIU_WET_PARTICLES_SCENE = preload("res://mods-unpacked/FengLiu-FengAddMods/particles/wet/unit_wet_particles.tscn")
# 潮湿雨滴：从身体顶部上方指定距离落下，覆盖到身体底部，尾巴不超出身体
const FENGLIU_WET_PARTICLES_TOP_MARGIN := 8.0
const FENGLIU_WET_PARTICLES_FALL_TIME := 0.32
const FENGLIU_WET_PARTICLES_GRAVITY := 300.0
const FENGLIU_WET_PARTICLES_TAIL_RATIO := 0.2
const FENGLIU_WET_PARTICLES_DROP_TEXTURE_HEIGHT := 48.0
# 冰冻向潮湿目标连锁传递的相邻半径（参考燃烧扩散 SpreadArea 半径 128）
const FENGLIU_FREEZE_SPREAD_RADIUS := 128.0

var _fengliu_knock_out_started := false
var _fengliu_scene_should_collide_with_borders := true

# 冰冻状态（定身型）
var _fengliu_is_frozen := false
var _fengliu_freeze_timer: Timer = null
var _fengliu_freeze_particles: CPUParticles2D = null
var _fengliu_freeze_saved_anim_speed := 1.0
var _fengliu_freeze_sounds: Array = []
var _fengliu_last_freeze_sound_msec: int = -100000

var _fengliu_is_wet := false
var _fengliu_wet_timer: Timer = null
var _fengliu_wet_particles = null


# 判断攻击来源是否匹配指定类型
func fengliu_key_in_class(key: String, hitbox: Hitbox = null) -> bool:
    # 通配符：匹配所有攻击来源（含 hitbox 为空的燃烧跳伤）
    if key == "*":
        return true
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
    # 记录场景原值：击出时临时关闭边界 clamp，池化复用时恢复
    _fengliu_scene_should_collide_with_borders = should_collide_with_borders
    _fengliu_knock_out_started = false
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


# 池化复用：恢复边界 clamp 与击出状态
func respawn() -> void :
    .respawn()
    _fengliu_knock_out_started = false
    set("_fengliu_ignore_knockback_resistance_percent", 0)
    should_collide_with_borders = _fengliu_scene_should_collide_with_borders
    # 冰冻状态不能跨池化复用（否则下一个敌人复活即「蓝身 + 物理处理关闭」）
    fengliu_clear_freeze()
    fengliu_clear_wet()


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


# 命中前读取攻击玩家的「无视击退抗性」次要属性
func _fengliu_apply_ignore_knockback_resistance(player_index: int) -> void:
    # 非玩家来源（DUMMY_PLAYER_INDEX，例如被魅惑的敌人打敌人）与越界索引不读属性：
    # Utils.get_stat 会直接访问 _stat_caches[player_index]，缓存只有 4 个槽位，
    # release 构建下越界得到 Nil，随后 Nil.get(hash) 会直接触发引擎 trap 闪退
    if player_index < 0 or player_index == RunData.DUMMY_PLAYER_INDEX or player_index >= RunData.get_player_count():
        set("_fengliu_ignore_knockback_resistance_percent", 0)
        return
        
    var value: float = Utils.get_stat(fengliu_ignore_knockback_resistance_hash, player_index)
    set("_fengliu_ignore_knockback_resistance_percent", int(clamp(int(value), 0, 100)))


# 扩展受伤结算
func take_damage(value: int, args: TakeDamageArgs) -> Array:
    var was_pending: bool = _pending_die
    var health_before: int = current_stats.health
    # 击中已冰冻目标时按武器词条放大伤害（本次命中才造成的冰冻不参与）
    value = fengliu_apply_frozen_bonus_damage(value, args)
    _fengliu_apply_ignore_knockback_resistance(args.from_player_index)
    var damage_taken = .take_damage(value, args)

    # 命中后触发魅惑
    var effects = RunData.get_player_effect(effect_fengliu_charm_enemy, args.from_player_index)
    if effects.size() > 0:
        fengliu_charm_enemy(effects[0], args)

    # 命中后判定冰冻（伤害已结算，避免冰冻爆伤提前击杀导致本次命中伤害丢失）
    fengliu_try_freeze_by_hit(args)
    # 命中后按武器词条施加潮湿（无概率，命中必触发）
    fengliu_try_apply_wet_by_hit(args)

    if args.from_player_index >= 0 and current_stats.health <= 0:
        # 击杀回盾量 = 槽内全部实例的效果数值之和；0 或负值不广播
        var regen = fengliu_get_killed_regen_shield_value(RunData.get_player_effect(effect_fengliu_killed_regen_shield, args.from_player_index))
        if regen > 0:
            RunData.emit_signal("fengliu_shield_regen", regen, args.from_player_index)

    # 命中时判定：效果 + 武器面板伤害 + 击退是否足以推出地图
    _fengliu_try_knock_out_of_map(args, value, health_before, was_pending)

    return damage_taken


# 从命中词条里取「对冰冻目标的伤害倍率」（多个词条取最大值；没有则 1.0）
func fengliu_get_frozen_bonus_multiplier(effects: Array) -> float:
    var multiplier: float = 1.0
    for effect in effects:
        if effect == null:
            continue
        # 哈希可能尚未生成，回退按 custom_key 字符串识别
        if effect.custom_key_hash != effect_fengliu_frozen_bonus_damage and effect.custom_key != "fengliu_frozen_bonus_damage":
            continue
        var raw = effect.get("multiplier")
        if raw == null:
            continue
        multiplier = max(multiplier, float(raw))

    return multiplier


# 冰冻目标被带该词条的武器命中时，按倍率放大最终伤害
func fengliu_apply_frozen_bonus_damage(value: int, args: TakeDamageArgs) -> int:
    if not _fengliu_is_frozen or args == null or args.hitbox == null:
        return value

    var multiplier: float = fengliu_get_frozen_bonus_multiplier(args.hitbox.effects)
    if multiplier <= 1.0:
        return value

    return int(round(value * multiplier))


# 读取攻击玩家的「击退出地图」效果阈值
# 返回 -1 = 没有效果；0 = 直接击出；>0 = 武器面板伤害阈值百分比
func _fengliu_get_knock_out_threshold(player_index: int) -> int:
    if player_index < 0:
        return -1

    var values = RunData.get_player_effect(effect_fengliu_knockback_out_of_map, player_index)

    # 兼容单值存档
    if values is int or values is float:
        return int(max(0, int(values)))

    if not (values is Array) or values.empty():
        return -1

    var threshold: int = -1
    for effect_value in values:
        if not (effect_value is int or effect_value is float):
            continue
        var current: int = int(max(0, int(effect_value)))
        # 多份效果取最宽松的阈值（0 最宽松）
        if threshold < 0 or current < threshold:
            threshold = current

    return threshold


# 命中时判定：效果 + 武器面板伤害 + 击退是否足以推出地图
func _fengliu_try_knock_out_of_map(args: TakeDamageArgs, weapon_damage: int, health_before: int, was_pending: bool) -> void:
    if was_pending or dead or cleaning_up or _fengliu_knock_out_started:
        return

    # 被魅惑的敌人是玩家侧单位，不参与击出
    if _is_charmed:
        return

    # 静态 / 运动学单位不参与（例如本 mod 的居民楼、地铁站 mode=3）
    if mode == MODE_KINEMATIC or mode == MODE_STATIC:
        return

    if stats == null:
        return

    if args == null or args.hitbox == null:
        return

    if not is_instance_valid(args.hitbox.from) or not (args.hitbox.from is Weapon):
        return

    if args.from_player_index < 0:
        return

    if weapon_damage <= 0 or health_before <= 0:
        return

    var threshold: int = _fengliu_get_knock_out_threshold(args.from_player_index)
    if threshold < 0:
        return

    # value = 0 时无伤害门槛；value > 0 时面板伤害必须严格超过当前生命的 value%
    if threshold > 0 and weapon_damage * 100 <= health_before * threshold:
        return

    # 已致死：只修饰原版死亡击退，不重复 die，保留全部原版击杀效果
    if _pending_die:
        var death_knockback: Vector2 = _die_args_unit.knockback_vector
        var resist_factor: float = 100.0 - stats.knockback_resistance * 100.0
        if not _fengliu_knock_out_reaches_edge(death_knockback * resist_factor):
            return

        _fengliu_knock_out_started = true
        should_collide_with_borders = false
        _die_args_unit.knockback_vector = death_knockback * FENGLIU_KNOCK_OUT_DEATH_KNOCKBACK
        return

    # 未致死：按击杀结算并击出
    if not _fengliu_knock_out_reaches_edge(get_knockback_value()):
        return

    _fengliu_knock_out_of_map(args)


# 剩余击退位移是否足以让当前位置越过区域边缘
func _fengliu_knock_out_reaches_edge(knockback_velocity: Vector2) -> bool:
    if knockback_velocity.length_squared() <= 0:
        return false

    var zone_rect: Rect2 = ZoneService.get_current_zone_rect()
    if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
        return false

    # 已经在区域外（例如出生在边缘）不处理，避免误杀
    if not zone_rect.has_point(global_position):
        return false

    # Unit.get_next_knockback_value() 每物理帧把 knockback_vector 乘 0.9，
    # 因此剩余总位移 ≈ 当前击退速度 × 物理帧 delta ÷ 0.1
    var remaining: Vector2 = knockback_velocity * (get_physics_process_delta_time() / FENGLIU_KNOCKBACK_DECAY_STEP)
    return not zone_rect.has_point(global_position + remaining)


# 击出地图：按击杀结算，并让尸体继续朝外飞出边界
func _fengliu_knock_out_of_map(args: TakeDamageArgs) -> void :
    _fengliu_knock_out_started = true
    _pending_die = true
    _can_move = false
    # 跳过 Unit._integrate_forces() 的边界 clamp；Entity.die() 会关闭碰撞，尸体可穿墙
    should_collide_with_borders = false

    # 与原版致死命中同一时点触发武器侧击杀效果
    if args != null and args.hitbox != null:
        args.hitbox.killed_something(self)

    var player_index: int = args.from_player_index if args != null else - 1
    if player_index < 0 or player_index >= players_ref.size():
        player_index = 0 if players_ref.size() > 0 else - 1

    var die_args = Entity.DieArgs.new()
    die_args.knockback_vector = knockback_vector * FENGLIU_KNOCK_OUT_DEATH_KNOCKBACK
    die_args.enemy_killed_by_player = true
    die_args.killed_by_player_index = player_index
    die_args.killing_blow_dmg_value = 0
    die_args.is_burning = _is_burning
    if player_index >= 0 and player_index < players_ref.size() and is_instance_valid(players_ref[player_index]):
        die_args.from = players_ref[player_index]

    call_deferred("die", die_args)



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


# 命中后判定冰冻
func fengliu_try_freeze_by_hit(args: TakeDamageArgs) -> void:
    if args == null or args.hitbox == null:
        return

    # 治疗类命中不触发
    if args.hitbox.is_healing:
        return

    if not fengliu_can_be_frozen():
        return

    # 被魅惑的敌人是玩家侧单位，其命中不触发冰冻
    var from = args.hitbox.from
    if not is_instance_valid(from) or from is Enemy:
        return

    fengliu_try_trigger_freeze(args.from_player_index)


# 燃烧跳伤判定冰冻：真实计时器每跳调用，在父类结算前掷骰
#   触发后会取消燃烧并按 R2 结算完（含双倍爆伤），本跳直接结束
func _on_BurningTimer_timeout() -> void:
    if _burning != null and not _fengliu_is_frozen and fengliu_can_be_frozen():
        fengliu_try_trigger_freeze(_burning_player_index)
        if _fengliu_is_frozen:
            return

    ._on_BurningTimer_timeout()


# 可上状态的目标：掉落物 / 被魅惑的宠物 / 已死亡或正在死亡都不处理
func fengliu_can_get_status() -> bool:
    return not (dead or _pending_die or is_loot or _is_charmed)


# 可被冰冻的目标（与通用状态守卫一致）
func fengliu_can_be_frozen() -> bool:
    return fengliu_can_get_status()


# 命中后按武器词条施加潮湿（无概率，命中必触发；多个词条取最长时长）
func fengliu_try_apply_wet_by_hit(args: TakeDamageArgs) -> void:
    if args == null or args.hitbox == null:
        return

    # 治疗类命中不触发
    if args.hitbox.is_healing:
        return

    if not fengliu_can_get_status():
        return

    # 被魅惑的敌人是玩家侧单位，其命中不触发潮湿
    var from = args.hitbox.from
    if not is_instance_valid(from) or from is Enemy:
        return

    var duration: float = fengliu_get_wet_duration_from_effects(args.hitbox.effects)
    # 溅射/衍生投射物（如拖把水弹）生成时不携带武器词条，回退到来源武器
    if duration <= 0.0 and from is Weapon:
        duration = fengliu_get_wet_duration_from_effects(from.effects)

    if duration <= 0.0:
        return

    fengliu_apply_wet(duration)


# 从效果数组里取潮湿时长（多个词条取最大值；没有潮湿词条返回 0）
func fengliu_get_wet_duration_from_effects(effects: Array) -> float:
    var duration := 0.0
    for effect in effects:
        if effect == null:
            continue
        # 哈希可能尚未生成，回退按 custom_key 字符串识别
        if effect.custom_key_hash != effect_fengliu_weapon_wet and effect.custom_key != "fengliu_weapon_wet":
            continue
        var value = effect.get("wet_duration")
        duration = max(duration, float(value) if value != null else FENGLIU_WET_DEFAULT_DURATION)

    return duration


# 冰冻音效列表：懒加载 mod 内复制的 4 段音效（缺失则跳过，不回退原版燃烧音）
func fengliu_get_freeze_sounds() -> Array:
    if _fengliu_freeze_sounds.empty():
        for path in FENGLIU_FREEZE_SOUND_PATHS:
            if not ResourceLoader.exists(path):
                continue
            var sound = load(path)
            if sound != null:
                _fengliu_freeze_sounds.push_back(sound)
    return _fengliu_freeze_sounds


# 播放一次冰冻音效（150ms 节流，随机取一段；与燃烧音同参数）
func fengliu_play_freeze_sound() -> void:
    var now: int = OS.get_ticks_msec()
    if now - _fengliu_last_freeze_sound_msec < FENGLIU_FREEZE_SOUND_MIN_INTERVAL_MSEC:
        return

    var sounds: Array = fengliu_get_freeze_sounds()
    if sounds.empty():
        return

    _fengliu_last_freeze_sound_msec = now
    SoundManager2D.play(Utils.get_rand_element(sounds), global_position, 0, 0.2)


# 按「冰冻概率」次要属性掷骰（%）
func fengliu_try_trigger_freeze(player_index: int) -> void:
    # 非玩家来源（DUMMY_PLAYER_INDEX）与越界索引不读属性：
    # 属性缓存只有 4 个玩家槽位，越界在 release 构建下会触发引擎 trap
    if player_index < 0 or player_index >= RunData.get_player_count():
        return

    var chance: float = fengliu_get_freeze_chance(player_index)
    if chance <= 0.0:
        return
    if not Utils.get_chance_success(clamp(chance / 100.0, 0.0, 1.0)):
        return

    fengliu_apply_freeze(FENGLIU_FREEZE_DURATION, player_index)


# 读取「冰冻概率」次要属性（%）：槽位由 RunData.get_player_effects 保证存在
func fengliu_get_freeze_chance(player_index: int) -> float:
    var raw = RunData.get_player_effects(player_index).get(fengliu_freeze_chance_hash, 0)
    if raw is int or raw is float:
        return float(raw)
    return 0.0


func fengliu_is_elite_or_boss() -> bool:
    return "is_elite" in self


# 施加冰冻：重复命中只刷新时长
func fengliu_apply_freeze(duration: float, source_player_index: int = -1) -> void:
    if duration <= 0.0 or dead or _pending_die:
        return

    # 传递时使用减半前的时长，避免精英/Boss 被减半两次
    var spread_duration: float = duration

    # 精英与 Boss 冰冻时长减半（刷新时长同样按减半后的值比较）
    if fengliu_is_elite_or_boss():
        duration *= 0.5

    # 首次冻结与刷新都播放冰霜音效（150ms 节流）
    fengliu_play_freeze_sound()

    if _fengliu_is_frozen:
        fengliu_refresh_freeze_time(duration)
        return

    # R2：先把原燃烧上下文拷出来（随后的燃烧跳伤会替换并清空燃烧状态）
    var had_burning: bool = _burning != null
    var burn_damage: int = int(_burning.damage) if had_burning else 0
    var burn_player_index: int = _burning_player_index
    var burn_from = _burning.from if had_burning else null
    var burn_scaling: Array = _burning.scaling_stats.duplicate() if had_burning else []
    var burn_is_global: bool = _burning.is_global_burn if had_burning else false
    var burn_tracking: String = _burning.tracking_key if had_burning else ""

    _fengliu_is_frozen = true

    # 定身前先清速度：否则 RigidBody 会沿用上一帧的 _integrate_forces_velocity 继续滑行
    _integrate_forces_velocity = Vector2.ZERO
    knockback_vector = Vector2.ZERO
    set_physics_process(false)

    # 变蓝 + 停住 idle 动画 + 冰霜粒子
    _set_color_modulation(FENGLIU_FREEZE_TINT)
    fengliu_pause_animation()
    fengliu_start_freeze_particles()

    fengliu_ensure_freeze_timer()
    _fengliu_freeze_timer.wait_time = duration
    _fengliu_freeze_timer.start()

    # 冰冻潮湿目标：向相邻的潮湿目标连锁传递（成功率 = 来源玩家的冰冻概率）
    if source_player_index >= 0 and _fengliu_is_wet:
        fengliu_spread_freeze_to_wet_neighbors(spread_duration, source_player_index)

    # R2：冻结生效后再结算，保证伤害跳在蓝色目标身上；
    # 走完整燃烧跳伤链（多重燃烧/燃烧减速/武器燃烧总和/统计），并在结束时取消燃烧。
    if had_burning:
        call("fengliu_settle_burn_tick", burn_damage, burn_player_index, burn_from, burn_scaling, burn_is_global, burn_tracking, 2.0)


# 向相邻的潮湿目标连锁传递冰冻：每个目标单独按冰冻概率掷骰；
# 新冻结的潮湿目标会继续传递，直到周围没有可被冻结的潮湿目标
func fengliu_spread_freeze_to_wet_neighbors(duration: float, source_player_index: int) -> void:
    var spawner = _entity_spawner_ref
    if spawner == null or not is_instance_valid(spawner):
        return

    var chance: float = clamp(fengliu_get_freeze_chance(source_player_index) / 100.0, 0.0, 1.0)
    if chance <= 0.0:
        return

    var radius_squared: float = FENGLIU_FREEZE_SPREAD_RADIUS * FENGLIU_FREEZE_SPREAD_RADIUS
    for other in spawner.get_all_enemies():
        if other == null or other == self or not is_instance_valid(other) or not (other is Enemy):
            continue
        # 只传递给「潮湿且尚未被冻结」的目标
        if not other._fengliu_is_wet or other._fengliu_is_frozen:
            continue
        if not other.fengliu_can_be_frozen():
            continue
        if global_position.distance_squared_to(other.global_position) > radius_squared:
            continue
        if not Utils.get_chance_success(chance):
            continue

        other.fengliu_apply_freeze(duration, source_player_index)


# 冰冻中再次命中：时长刷新为「剩余 / 新时长」中的较大值
func fengliu_refresh_freeze_time(duration: float) -> void:
    fengliu_ensure_freeze_timer()
    var remaining: float = _fengliu_freeze_timer.time_left
    if duration > remaining:
        _fengliu_freeze_timer.wait_time = duration
        _fengliu_freeze_timer.start()


# 解除冰冻（幂等）：恢复物理处理、去色、恢复动画、停粒子
func fengliu_clear_freeze() -> void:
    if _fengliu_freeze_timer != null and is_instance_valid(_fengliu_freeze_timer):
        _fengliu_freeze_timer.stop()

    if not _fengliu_is_frozen:
        return

    _fengliu_is_frozen = false
    set_physics_process(true)
    remove_color_modulation(FENGLIU_FREEZE_TINT)
    fengliu_resume_animation()
    fengliu_stop_freeze_particles()


func fengliu_ensure_freeze_timer() -> void:
    if _fengliu_freeze_timer != null and is_instance_valid(_fengliu_freeze_timer):
        return

    _fengliu_freeze_timer = Timer.new()
    _fengliu_freeze_timer.name = "FengliuFreezeTimer"
    _fengliu_freeze_timer.one_shot = true
    add_child(_fengliu_freeze_timer)
    _fengliu_freeze_timer.connect("timeout", self, "_fengliu_on_freeze_timeout")


func _fengliu_on_freeze_timeout() -> void:
    fengliu_clear_freeze()


# 冻结时停住 idle 动画；解冻/死亡前恢复，保证死亡动画正常播放
func fengliu_pause_animation() -> void:
    if _animation_player == null:
        return
    _fengliu_freeze_saved_anim_speed = _animation_player.playback_speed
    _animation_player.playback_speed = 0.0


func fengliu_resume_animation() -> void:
    if _animation_player == null:
        return
    _animation_player.playback_speed = _fengliu_freeze_saved_anim_speed


func fengliu_start_freeze_particles() -> void:
    if _fengliu_freeze_particles == null or not is_instance_valid(_fengliu_freeze_particles):
        _fengliu_freeze_particles = FENGLIU_FREEZE_PARTICLES_SCENE.instance()
        _fengliu_freeze_particles.name = "FengliuFreezeParticles"
        # 与燃烧粒子同款位置：对齐单位贴图中心
        if _animation != null:
            _fengliu_freeze_particles.position = _animation.position
        add_child(_fengliu_freeze_particles)

    _fengliu_freeze_particles.visible = true
    _fengliu_freeze_particles.emitting = true


func fengliu_stop_freeze_particles() -> void:
    if _fengliu_freeze_particles == null or not is_instance_valid(_fengliu_freeze_particles):
        return
    _fengliu_freeze_particles.emitting = false
    _fengliu_freeze_particles.visible = false


# 施加潮湿：重复命中只刷新为更长的剩余时长
func fengliu_apply_wet(duration: float) -> void:
    if duration <= 0.0 or dead or _pending_die:
        return

    # 潮湿会取消燃烧（只取消状态，不结算伤害）
    if _burning != null:
        stop_burning()

    fengliu_ensure_wet_timer()

    # 已潮湿：只刷新为更长的剩余时长
    if _fengliu_is_wet:
        var remaining: float = _fengliu_wet_timer.time_left
        if duration > remaining:
            _fengliu_wet_timer.wait_time = duration
            _fengliu_wet_timer.start()
        return

    # 首次潮湿：上雨滴粒子并开始计时
    _fengliu_is_wet = true
    fengliu_start_wet_particles()
    _fengliu_wet_timer.wait_time = duration
    _fengliu_wet_timer.start()


# 解除潮湿（幂等）
func fengliu_clear_wet() -> void:
    # 无论当前状态如何都先停表，避免残留计时
    if _fengliu_wet_timer != null and is_instance_valid(_fengliu_wet_timer):
        _fengliu_wet_timer.stop()

    if not _fengliu_is_wet:
        return

    _fengliu_is_wet = false
    fengliu_stop_wet_particles()


func fengliu_ensure_wet_timer() -> void:
    if _fengliu_wet_timer != null and is_instance_valid(_fengliu_wet_timer):
        return

    # 懒创建一次性计时器
    _fengliu_wet_timer = Timer.new()
    _fengliu_wet_timer.name = "FengliuWetTimer"
    _fengliu_wet_timer.one_shot = true
    add_child(_fengliu_wet_timer)
    _fengliu_wet_timer.connect("timeout", self, "_fengliu_on_wet_timeout")


func _fengliu_on_wet_timeout() -> void:
    fengliu_clear_wet()


func fengliu_start_wet_particles() -> void:
    # 身体范围取自 Hurtbox 圆形碰撞；缺失时用默认值（高 56、半径 16）
    var body_radius: float = 16.0
    var body_top: float = -48.0
    var body_bottom: float = 8.0
    var hurtbox = get_node_or_null("Hurtbox")
    if hurtbox != null:
        var collision = hurtbox.get_node_or_null("Collision")
        if collision != null and collision.shape is CircleShape2D:
            body_radius = collision.shape.radius
        body_top = hurtbox.position.y - body_radius
        body_bottom = hurtbox.position.y + body_radius

    if _fengliu_wet_particles == null or not is_instance_valid(_fengliu_wet_particles):
        _fengliu_wet_particles = FENGLIU_WET_PARTICLES_SCENE.instance()
        _fengliu_wet_particles.name = "FengliuWetParticles"
        add_child(_fengliu_wet_particles)

    # 发射点：身体顶部上方 8px；矩形发射保证雨滴全部从头顶上方落下
    var emitter_x: float = _animation.position.x if _animation != null else 0.0
    var emitter_y: float = body_top - FENGLIU_WET_PARTICLES_TOP_MARGIN
    _fengliu_wet_particles.position = Vector2(emitter_x, emitter_y)
    _fengliu_wet_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    _fengliu_wet_particles.emission_rect_extents = Vector2(max(6.0, body_radius * 0.8), 2.0)

    # 雨滴长度（尾巴）按身体高度取比例，避免垂出身体底部
    var body_height: float = max(1.0, body_bottom - body_top)
    var tail_length: float = clamp(body_height * FENGLIU_WET_PARTICLES_TAIL_RATIO, 8.0, 24.0)
    _fengliu_wet_particles.scale_amount = tail_length / FENGLIU_WET_PARTICLES_DROP_TEXTURE_HEIGHT
    _fengliu_wet_particles.scale_amount_random = 0.05

    # 由下落距离反解初速：雨滴底端刚好到身体底部（覆盖整只敌人、不超出）
    var fall_distance: float = max(8.0, body_bottom - emitter_y - tail_length)
    var fall_time: float = FENGLIU_WET_PARTICLES_FALL_TIME
    var gravity_y: float = FENGLIU_WET_PARTICLES_GRAVITY
    _fengliu_wet_particles.lifetime = fall_time
    _fengliu_wet_particles.gravity = Vector2(0, gravity_y)
    _fengliu_wet_particles.initial_velocity = max(0.0, (fall_distance - 0.5 * gravity_y * fall_time * fall_time) / fall_time)
    _fengliu_wet_particles.initial_velocity_random = 0.05
    _fengliu_wet_particles.amount = int(clamp(body_radius * 0.6, 8.0, 20.0))

    _fengliu_wet_particles.visible = true
    _fengliu_wet_particles.emitting = true


func fengliu_stop_wet_particles() -> void:
    if _fengliu_wet_particles == null or not is_instance_valid(_fengliu_wet_particles):
        return
    # 停止发射并隐藏（节点保留给下次复用）
    _fengliu_wet_particles.emitting = false
    _fengliu_wet_particles.visible = false


# R3：冰冻期间受到燃烧 → 不点燃，改为按燃烧跳伤链结算一次双倍该燃烧单跳伤害
func apply_burning(burning_data: BurningData) -> void:
    if _fengliu_is_frozen:
        if burning_data != null and not dead and not _pending_die:
            # 冰冻中受到燃烧：播放冰冻音效（与首次冻结同 4 段）
            fengliu_play_freeze_sound()
            # 同 R2：用 call() 调用 unit 扩展里的方法，避免扩展编译顺序导致的 parse error
            call("fengliu_settle_burn_tick",
                int(burning_data.damage),
                fengliu_get_burn_player_index(burning_data),
                burning_data.from,
                burning_data.scaling_stats.duplicate(),
                burning_data.is_global_burn,
                burning_data.tracking_key,
                2.0)
        return

    # 潮湿期间不能点燃（静默忽略，不结算伤害）
    if _fengliu_is_wet:
        return

    .apply_burning(burning_data)


# 与基类 apply_burning 同口径：优先攻击来源，其次沿用上次来源，最后随机
func fengliu_get_burn_player_index(burning_data: BurningData) -> int:
    var from = burning_data.from
    if is_instance_valid(from):
        return from.player_index
    if _burning_player_index >= 0:
        return _burning_player_index

    var player_count: int = RunData.get_player_count()
    if player_count <= 0:
        return 0
    return Utils.randi() % player_count


# 池化复用 / 死亡 / 清场：先解除冰冻，避免「蓝色 + 关闭物理处理」带到下一次使用
func die(args: Entity.DieArgs = Utils.default_die_args) -> void:
    fengliu_clear_freeze()
    fengliu_clear_wet()
    .die(args)


func despawn() -> void:
    fengliu_clear_freeze()
    fengliu_clear_wet()
    .despawn()

