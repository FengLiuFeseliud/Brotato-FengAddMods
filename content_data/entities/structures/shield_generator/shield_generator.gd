class_name ShieldGenerator
extends Structure


# 区域光环配色
const AREA_COLOR: = Color(0.25, 0.6, 1.0)
# 区域半透明度
const AREA_ALPHA: = 0.25
# 光环贴图半径（aura_effect.png 为 250x250，半径 125）
const AURA_TEXTURE_RADIUS: = 125.0
# 每次攻击给区域内玩家回复的护盾值（默认值；被诅咒时由效果资源给出更大的值）
const SHIELD_REGEN_DEFAULT: = 1
# 关闭前的基础攻击次数（默认值；实际由效果资源给出）
const CLOSE_AFTER_ATTACKS_BASE: = 5
# 每 1 点工程学增加的攻击次数比例（默认值）
const ENGINEERING_ATTACK_RATE: = 0.1
# 关闭区域后的冷却时长（秒，默认值）
const CLOSE_DURATION: = 3.0
# 伤害追踪键
const DAMAGE_TRACKING_KEY: = "item_shield_generator"

onready var _shield_shape: CollisionShape2D = $ShieldArea / CollisionShape2D
onready var _aura: Sprite = $ShieldArea / Aura
onready var _center_icon: Sprite = $ShieldArea / CenterIcon
onready var _icon_anim: AnimationPlayer = $ShieldArea / IconAnimationPlayer
onready var _attack_bar: UIProgressBar = $AttackBar
onready var _hitbox: Hitbox = $Hitbox

# 当前停留在区域内的敌人（进入入队、离开出队）
var _enemies_in_area: Array = []
# 当前停留在区域内的玩家（进入入队、离开出队）
var _players_in_area: Array = []
# 每次攻击给区域内玩家回复的护盾值
var _shield_regen: int = SHIELD_REGEN_DEFAULT
# 攻击冷却（tick，60 tick = 1 秒）
var _cooldown: float = 0.0
# 本次开启能打多少次
var _attacks_before_close: int = CLOSE_AFTER_ATTACKS_BASE
# 本次开启已打次数
var _attacks_done: int = 0
# 关闭剩余时间（秒），大于 0 表示正在冷却
var _close_time_left: float = 0.0
# 关闭机制参数（来自效果资源，缺失时用常量默认值）
var _close_after_attacks_base: int = CLOSE_AFTER_ATTACKS_BASE
var _engineering_attack_rate: float = ENGINEERING_ATTACK_RATE
var _close_duration: float = CLOSE_DURATION
var _hitbox_args: = Hitbox.HitboxArgs.new()


# 生成时套用盾条配色，并按炮塔口径准备好命中判定
func set_data(data: Resource) -> void:
	# 先走构筑物基类的数据初始化（算好 stats），再刷新区域外观与命中判定
	.set_data(data)
	apply_area_visual()
	_apply_hitbox_stats()
	# 回盾量与关闭机制参数来自效果资源，缺失时用默认值
	var regen = data.get("shield_regen") if data != null else null
	_shield_regen = int(regen) if regen != null else SHIELD_REGEN_DEFAULT
	var base_attacks = data.get("close_after_attacks_base") if data != null else null
	_close_after_attacks_base = int(base_attacks) if base_attacks != null else CLOSE_AFTER_ATTACKS_BASE
	var attack_rate = data.get("engineering_attack_rate") if data != null else null
	_engineering_attack_rate = float(attack_rate) if attack_rate != null else ENGINEERING_ATTACK_RATE
	var duration = data.get("close_duration") if data != null else null
	_close_duration = float(duration) if duration != null else CLOSE_DURATION
	# 关闭阈值
	var engineering: float = Utils.get_stat(Keys.stat_engineering_hash, player_index)
	_attacks_before_close = int(max(1, _close_after_attacks_base + int(engineering * _engineering_attack_rate)))
	# 新生成即处于开启态
	_attacks_done = 0
	_close_time_left = 0.0
	_set_area_closed(false)
	_cooldown = 0.0

	# 被诅咒时的光效：紫色诅咒粒子 + 中心图标紫色描边
	if is_cursed and not is_instance_valid(curse_particle_instance):
		curse_particle_instance = curse_particles.instance()
		add_child(curse_particle_instance)
		_apply_curse_outline()

	# 伤害追踪
	_hitbox.damage_tracking_key_hash = Keys.generate_hash(DAMAGE_TRACKING_KEY)
	_hitbox.from = self


func apply_area_visual() -> void:
	_aura.modulate = Color(AREA_COLOR.r, AREA_COLOR.g, AREA_COLOR.b, AREA_ALPHA)

	# 射程为 0 时不改形状，保留场景里的默认半径
	var radius: float = float(stats.max_range) if stats != null else 0.0
	if radius <= 0.0:
		return

	# 形状与光环一起按半径缩放
	_shield_shape.shape.radius = radius
	var scale_factor: float = radius / AURA_TEXTURE_RADIUS
	_aura.scale = Vector2(scale_factor, scale_factor)


func _apply_hitbox_stats() -> void:
	if stats == null:
		return

	_hitbox_args.set_from_weapon_stats(stats)
	_hitbox.effect_scale = stats.effect_scale
	_hitbox.from = self
	_hitbox.set_damage(stats.damage, _hitbox_args)
	_hitbox.speed_percent_modifier = stats.speed_percent_modifier
	_hitbox.set_knockback(Vector2.ZERO, stats.knockback, stats.knockback_piercing)


# 怪物与玩家进入区域：玩家登记为回盾对象，敌人登记为伤害对象
func _on_ShieldArea_body_entered(body: Node) -> void:
	if body is Player:
		# 同一玩家重复进入时去重
		if not _players_in_area.has(body):
			_players_in_area.append(body)
		return

	if not (body is Enemy):
		return

	# 同一敌人重复进入时去重
	if _enemies_in_area.has(body):
		return

	_enemies_in_area.append(body)


# 怪物与玩家离开区域
func _on_ShieldArea_body_exited(body: Node) -> void:
	# 两个列表都尝试移除（不在列表里的单位是空操作）
	_enemies_in_area.erase(body)
	_players_in_area.erase(body)


# 持续在区域内：按炮塔攻击速度周期性结算；打满次数后关闭区域并冷却
func _physics_process(delta: float) -> void:
	if dead or stats == null:
		return

	# 剩余攻击次数条随状态刷新
	_update_attack_bar()

	# 关闭期间：只倒计时，不结算任何效果
	if _close_time_left > 0.0:
		_close_time_left -= delta
		if _close_time_left <= 0.0:
			_set_area_closed(false)
			# 重开后立即打第一下
			_cooldown = 0.0
		return

	_cooldown -= 60.0 * delta
	if _cooldown > 0.0:
		return

	# 中继器加成：只加速节奏，不改「关闭前攻击次数」
	_cooldown = fengliu_apply_relay_attack_speed_to_cooldown(WeaponService.apply_structure_attack_speed_effects(stats.cooldown, player_index))
	var has_enemies: bool = _damage_enemies_in_area()
	var has_players: bool = _regen_players_in_area()

	# 区域内无人
	if not has_enemies and not has_players:
		return

	# 有目标才算一次攻击
	_icon_anim.play("attack")
	_attacks_done += 1
	if _attacks_done >= _attacks_before_close:
		_attacks_done = 0
		_close_time_left = _close_duration
		_set_area_closed(true)


# 对区域内所有敌人结算一次伤害
func _damage_enemies_in_area() -> bool:
	var targets: = []
	for enemy in _enemies_in_area:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.get_charmed_by_player_index() >= 0:
			continue
		targets.append(enemy)
	_enemies_in_area = targets

	if targets.size() == 0:
		return false

	# 同一帧共用一个命中判定
	for enemy in targets:
		var args: = TakeDamageArgs.new(player_index, _hitbox)
		args.from = self
		var dmg_taken: Array = enemy.take_damage(_hitbox.damage, args)
		_hitbox.hit_something(enemy, dmg_taken[1])

	return true


# 对区域内所有存活玩家回盾
func _regen_players_in_area() -> bool:
	var alive: = []
	for player in _players_in_area:
		if not is_instance_valid(player) or player.dead:
			continue
		alive.append(player)
	_players_in_area = alive

	# 回盾量取自效果资源（被诅咒时更大），节奏＝本次攻击
	for player in alive:
		player.fengliu_shield_regen(_shield_regen)

	return alive.size() > 0


# 区域开关
func _set_area_closed(closed: bool) -> void:
	_aura.visible = not closed
	_center_icon.visible = true


# 剩余攻击次数条
func _update_attack_bar() -> void:
	# 关闭期间显示空条
	if _attack_bar == null:
		return

	var total: float = float(max(1, _attacks_before_close))
	var remaining: float = 0.0 if _close_time_left > 0.0 else max(0.0, total - float(_attacks_done))
	_attack_bar.value = remaining / total * 100.0


# 给中心图标套上诅咒紫色描边
func _apply_curse_outline() -> void:
	var mat: = ShaderMaterial.new()
	mat.shader = outline_material.shader
	mat.set_shader_param("texture_size", _center_icon.texture.get_size())
	mat.set_shader_param("width", 3.0)
	mat.set_shader_param("alpha", 1.0)
	mat.set_shader_param("desaturation", 0.0)
	mat.set_shader_param("outline_color_0", Utils.CURSE_COLOR)
	_center_icon.material = mat
