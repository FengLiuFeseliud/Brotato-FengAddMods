extends Node2D
# 月牙法杖的环绕月牙：持有时围着玩家旋转，接触敌人造成本武器伤害。
# 环绕半径与命中半径一致，均为「武器面板射程(max_range) + radius_bonus」。

# 环绕/命中半径 = 武器面板射程 + 该值
export (float) var radius_bonus: = 50.0
# 命中判定圆半径 = 环绕半径 × 该比例（默认 1.0，两者一致）
export (float) var hitbox_radius_ratio: = 1.0
# 转一圈耗时 = 武器冷却秒数 × 该系数（越小转得越快）
export (float) var orbit_cooldown_factor: = 4.0
# 命中间隔 = 武器冷却秒数 × 该系数
export (float) var hit_interval_factor: = 1.0
# 单次命中伤害 = 武器面板伤害 × 该比例
export (float) var damage_ratio: = 1.0
# 起始相位（需要多把同名武器的月牙错开时手动设置）
export (float) var phase_offset: = 0.0
# 贴图朝向圆周切线的角度偏移（默认 +PI/2 = 运动方向；想反向贴图改成 -PI/2）
export (float) var tangent_rotation_offset: = PI / 2
# 贴图缩放基准：环绕半径等于该值时，贴图缩放 = sprite_base_scale
export (float) var sprite_base_radius: = 350.0
# 基准半径下的贴图缩放（2.0 = 96×96 贴图在基准半径下显示为 192×192）
export (float) var sprite_base_scale: = 2.0

var _weapon = null
var _player = null
var _angle: = 0.0
var _current_cooldown: = 0.0
var _hitbox_active: = false
var _last_hitbox_radius: = - 1.0

onready var _hitbox: Hitbox = $Hitbox
onready var _hitbox_shape: CollisionShape2D = $Hitbox/Collision
onready var _sprite: Sprite = $Sprite


func _ready() -> void :
	z_index = 0
	# 子节点先于武器 _ready，等武器属性初始化完成后再取引用
	call_deferred("_auto_setup")


func _auto_setup() -> void :
	# 探针或外部已显式注入时不再自动识别
	if _weapon != null:
		return

	var weapon = get_parent()
	if weapon == null:
		return
	if not (weapon is Weapon) and not ("weapon_pos" in weapon):
		return

	# 只有真正装备在玩家武器栏上的武器才召唤月牙（weapon_pos = -1 的宠物武器等不召唤）
	if weapon.weapon_pos < 0:
		visible = false
		set_physics_process(false)
		return

	# 武器挂在 Player/Weapons 容器下，必须跳过容器拿到真正的 Player（容器没有 current_weapons）
	var owner_player = _find_owner_player(weapon)
	if owner_player == null:
		visible = false
		set_physics_process(false)
		return

	setup(weapon, owner_player)


func _find_owner_player(weapon):
	var node = weapon.get_parent()
	while node != null:
		if node is Node2D and ("current_weapons" in node):
			return node
		node = node.get_parent()
	return null


# 供外部显式注入武器与玩家（游戏内由 _auto_setup 自动调用）
func setup(weapon, player) -> void :
	_weapon = weapon
	_player = player
	if not is_instance_valid(_weapon) or not is_instance_valid(_player):
		return

	_hitbox.from = _weapon
	_hitbox.player_attack_id = - 1

	if not _hitbox.is_connected("hit_something", self, "_on_Hitbox_hit_something"):
		_hitbox.connect("hit_something", self, "_on_Hitbox_hit_something")
	if not _hitbox.is_connected("killed_something", _weapon, "on_killed_something"):
		_hitbox.connect("killed_something", _weapon, "on_killed_something", [_hitbox])
	if not _hitbox.is_connected("critically_hit_something", _weapon, "_on_weapon_critically_hit_something"):
		_hitbox.connect("critically_hit_something", _weapon, "_on_weapon_critically_hit_something")
	if not _hitbox.is_connected("one_shot_something", _weapon, "on_one_shot_something"):
		_hitbox.connect("one_shot_something", _weapon, "on_one_shot_something")
	if not _hitbox.is_connected("added_gold_on_crit", _weapon, "on_added_gold_on_crit"):
		_hitbox.connect("added_gold_on_crit", _weapon, "on_added_gold_on_crit")


func _physics_process(delta: float) -> void :
	if not is_instance_valid(_weapon) or not is_instance_valid(_player):
		return
	if not is_instance_valid(_hitbox):
		return

	# 上一个 tick 的命中判定只保留一个物理帧（同原版 Ratzilla 的写法）
	if _hitbox_active:
		_hitbox.disable()
		_hitbox_active = false

	var stats = _weapon.current_stats
	if stats == null or not ("max_range" in stats) or not ("cooldown" in stats):
		return

	var cooldown_frames: float = max(1.0, float(stats.cooldown))
	var radius: float = max(0.0, float(stats.max_range) + radius_bonus)
	var rotation_speed: float = TAU / max(0.05, (cooldown_frames / 60.0) * orbit_cooldown_factor)

	_angle += rotation_speed * delta
	var orbit_angle: float = _angle + phase_offset + _get_distributed_phase()
	global_position = _player.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * radius
	# 武器根节点会随瞄准旋转，这里用全局旋转覆盖，保证命中判定不被带歪
	global_rotation = 0.0
	# 贴图只做表现：始终朝圆周切线方向，并随环绕半径等比放大（不缩放根节点，避免连带放大命中圆）
	_sprite.global_rotation = orbit_angle + tangent_rotation_offset
	var sprite_scale: float = sprite_base_scale * (radius / max(1.0, sprite_base_radius))
	_sprite.global_scale = Vector2(sprite_scale, sprite_scale)

	var hitbox_radius: float = radius * hitbox_radius_ratio
	if abs(hitbox_radius - _last_hitbox_radius) > 0.01:
		_last_hitbox_radius = hitbox_radius
		var shape = _hitbox_shape.shape
		if shape is CircleShape2D:
			shape.radius = max(1.0, hitbox_radius)

	_current_cooldown = max(_current_cooldown - Utils.physics_one(delta), 0)
	if _current_cooldown <= 0:
		_attack(stats, orbit_angle)
		_current_cooldown = cooldown_frames * hit_interval_factor


# 多把月牙法杖时按数量均分圆周（同原版水母 pet 的相位分配）
func _get_distributed_phase() -> float:
	if _player == null or not ("current_weapons" in _player):
		return 0.0

	var moons = []
	for weapon in _player.current_weapons:
		if not is_instance_valid(weapon):
			continue
		var moon = weapon.get_node_or_null("Moon")
		if moon != null and moon.get_script() == get_script():
			moons.push_back(moon)

	var count = moons.size()
	if count <= 1:
		return 0.0
	var index = moons.find(self)
	if index < 0:
		return 0.0
	return (TAU / count) * index


func _attack(stats, orbit_angle: float) -> void :
	# 与武器自身 hitbox 完全同源：伤害/暴击/燃烧/效果/命中溅射全部按武器结算
	var weapon_hitbox = null
	if "_hitbox" in _weapon:
		weapon_hitbox = _weapon._hitbox

	if weapon_hitbox != null:
		_hitbox.effect_scale = weapon_hitbox.effect_scale
		_hitbox.damage = max(1, int(round(float(weapon_hitbox.damage) * damage_ratio)))
		_hitbox.scaling_stats = weapon_hitbox.scaling_stats
		_hitbox.accuracy = weapon_hitbox.accuracy
		_hitbox.crit_chance = weapon_hitbox.crit_chance
		_hitbox.crit_damage = weapon_hitbox.crit_damage
		_hitbox.burning_data = weapon_hitbox.burning_data
		_hitbox.is_healing = weapon_hitbox.is_healing
		_hitbox.effects = weapon_hitbox.effects
		_hitbox.speed_percent_modifier = weapon_hitbox.speed_percent_modifier
		_hitbox.projectiles_on_hit = weapon_hitbox.projectiles_on_hit
	else:
		# 回退：直接从武器当前属性拼（正常游戏不会走到这里）
		var hitbox_args: = Hitbox.HitboxArgs.new().set_from_weapon_stats(stats)
		_hitbox.effect_scale = stats.effect_scale
		_hitbox.set_damage(max(1, int(round(float(stats.damage) * damage_ratio))), hitbox_args)
		_hitbox.speed_percent_modifier = stats.speed_percent_modifier
		_hitbox.effects = _weapon.effects
		_hitbox.projectiles_on_hit = []

	_hitbox.from = _weapon
	# 每次 tick 等价于武器的一次攻击（按攻击 ID 记账的击杀/命中效果与武器一致）
	_hitbox.player_attack_id = _get_next_attack_id()

	# 击退方向取「玩家 → 月牙」的径向，把敌人向外推
	_hitbox.set_knockback(Vector2(cos(orbit_angle), sin(orbit_angle)), stats.knockback, stats.knockback_piercing)

	_hitbox.ignored_objects.clear()
	_hitbox.enable()
	_hitbox_active = true


# 复用武器自己的攻击 ID 计数器，让月牙每次 tick 在结算上等价于武器的一次攻击
func _get_next_attack_id() -> int:
	if not is_instance_valid(_weapon):
		return - 1
	var behavior = _weapon.get_node_or_null("ShootingBehavior")
	if behavior != null and behavior.has_method("_get_next_attack_id"):
		return behavior._get_next_attack_id()
	return - 1


func _on_Hitbox_hit_something(thing_hit, damage_dealt: int) -> void :
	if not is_instance_valid(_weapon):
		return

	# 与原版武器命中一致：先结算生命偷取，再把伤害记到本武器
	if _weapon.current_stats != null:
		RunData.manage_life_steal(_weapon.current_stats, _weapon.player_index)
	if "weapon_pos" in _weapon and _weapon.weapon_pos >= 0:
		_weapon.on_weapon_hit_something(thing_hit, damage_dealt, _hitbox)
