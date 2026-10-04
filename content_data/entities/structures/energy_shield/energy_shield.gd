class_name EnergyShield
extends Structure


# 区域光环配色：与盾条同色（extensions/main.gd 的 FENGLIU_STATUS_COLOR_SHIELD）
const AREA_COLOR: = Color(0.25, 0.6, 1.0)
# 区域半透明度
const AREA_ALPHA: = 0.25
# 光环贴图半径（aura_effect.png 为 250x250，半径 125）
const AURA_TEXTURE_RADIUS: = 125.0
# 每次攻击给区域内玩家回复的护盾值（默认值；被诅咒时由效果资源给出更大的值）
const SHIELD_REGEN_DEFAULT: = 1
# 关闭前的基础攻击次数（实际＝基础 + 每 1 点工程学 +10%，至少 1 次）
const CLOSE_AFTER_ATTACKS_BASE: = 5
# 每 1 点工程学增加的攻击次数比例
const ENGINEERING_ATTACK_RATE: = 0.1
# 关闭区域后的冷却时长（秒）
const CLOSE_DURATION: = 3.0

onready var _shield_shape: CollisionShape2D = $ShieldArea / CollisionShape2D
onready var _aura: Sprite = $ShieldArea / Aura
onready var _center_icon: Sprite = $ShieldArea / CenterIcon
onready var _icon_anim: AnimationPlayer = $ShieldArea / IconAnimationPlayer
onready var _hitbox: Hitbox = $Hitbox

# 当前停留在区域内的敌人（进入入队、离开出队）
var _enemies_in_area: Array = []
# 当前停留在区域内的玩家（进入入队、离开出队）
var _players_in_area: Array = []
# 每次攻击给区域内玩家回复的护盾值（来自效果资源，被诅咒时更大）
var _shield_regen: int = SHIELD_REGEN_DEFAULT
# 攻击冷却（tick，60 tick = 1 秒）
var _cooldown: float = 0.0
# 本次开启能打多少次（按工程学算，见 set_data）
var _attacks_before_close: int = CLOSE_AFTER_ATTACKS_BASE
# 本次开启已打次数
var _attacks_done: int = 0
# 关闭剩余时间（秒），大于 0 表示正在冷却
var _close_time_left: float = 0.0
var _hitbox_args: = Hitbox.HitboxArgs.new()


# 生成时套用盾条配色，并按炮塔口径准备好命中判定
func set_data(data: Resource) -> void:
	# 先走构筑物基类的数据初始化（算好 stats），再刷新区域外观与命中判定
	.set_data(data)
	apply_area_visual()
	_apply_hitbox_stats()
	# 回盾量来自效果资源（被诅咒时更大），效果未带该字段时用默认值
	var regen = data.get("shield_regen") if data != null else null
	_shield_regen = int(regen) if regen != null else SHIELD_REGEN_DEFAULT
	# 关闭阈值：基础 5 次 + 每 1 点工程学 +10%，至少 1 次
	var engineering: float = Utils.get_stat(Keys.stat_engineering_hash, player_index)
	_attacks_before_close = max(1, CLOSE_AFTER_ATTACKS_BASE + int(engineering * ENGINEERING_ATTACK_RATE))
	# 新生成即处于开启态
	_attacks_done = 0
	_close_time_left = 0.0
	_set_area_closed(false)
	# 进场后可立即攻击一次（首个 tick 不必等冷却）
	_cooldown = 0.0


# 把盾条配色写到光环上，并按射程确定区域半径
func apply_area_visual() -> void:
	# 半透明区域：颜色与盾条完全一致
	_aura.modulate = Color(AREA_COLOR.r, AREA_COLOR.g, AREA_COLOR.b, AREA_ALPHA)

	# 射程为 0 时不改形状，保留场景里的默认半径
	var radius: float = float(stats.max_range) if stats != null else 0.0
	if radius <= 0.0:
		return

	# 形状与光环一起按半径缩放（形状 resource_local_to_scene，不会污染其它实例）
	_shield_shape.shape.radius = radius
	var scale_factor: float = radius / AURA_TEXTURE_RADIUS
	_aura.scale = Vector2(scale_factor, scale_factor)


# 用构筑物属性配置命中判定（伤害 / 暴击 / 击退 / 缩放），与炮塔同口径
func _apply_hitbox_stats() -> void:
	if stats == null:
		return

	# 命中判定只是伤害参数载体：不参与任何碰撞，也不会被敌人的 Hurtbox 检测到
	_hitbox_args.set_from_weapon_stats(stats)
	_hitbox.effect_scale = stats.effect_scale
	_hitbox.from = self
	_hitbox.set_damage(stats.damage, _hitbox_args)
	_hitbox.speed_percent_modifier = stats.speed_percent_modifier
	# 方向留空：由被击中方按「远离攻击者」自行推导击退方向
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

	# 关闭期间：只倒计时，不结算任何效果
	if _close_time_left > 0.0:
		_close_time_left -= delta
		if _close_time_left <= 0.0:
			_set_area_closed(false)
			# 重开后立即打第一下
			_cooldown = 0.0
		return

	# 冷却按 tick 递减（60 tick / 秒）
	_cooldown -= 60.0 * delta
	if _cooldown > 0.0:
		return

	# 攻击间隔吃「构造物攻击速度」（与炮塔同一换算口径）
	_cooldown = WeaponService.apply_structure_attack_speed_effects(stats.cooldown, player_index)
	# 同一次攻击：对区域内敌人结算伤害，并给区域内玩家回盾
	# 必须分开调用：用 or 连写会短路，后者不会被执行
	var has_enemies: bool = _damage_enemies_in_area()
	var has_players: bool = _regen_players_in_area()

	# 区域内无人：本次不算一次攻击（不计数、不播动画、不关闭）
	if not has_enemies and not has_players:
		return

	# 有目标才算一次攻击：播放图标攻击动画并累计次数
	_icon_anim.play("attack")
	_attacks_done += 1
	if _attacks_done >= _attacks_before_close:
		_attacks_done = 0
		_close_time_left = CLOSE_DURATION
		_set_area_closed(true)


# 对区域内所有敌人结算一次伤害（返回区域内是否有有效敌人）
func _damage_enemies_in_area() -> bool:
	# 先剔除已死亡 / 已释放 / 被魅惑（友方）的单位
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

	# 同一帧共用一个命中判定，逐个结算（与原版爆炸同款做法）
	for enemy in targets:
		var args: = TakeDamageArgs.new(player_index, _hitbox)
		args.from = self
		enemy.take_damage(_hitbox.damage, args)

	return true


# 对区域内所有存活玩家回盾（满盾 / 禁回盾由玩家侧回盾接口自行处理，返回区域内是否有玩家）
func _regen_players_in_area() -> bool:
	# 先剔除已死亡 / 已释放的玩家
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


# 区域开 / 关：关闭时只隐藏区域光环，中心图标恒显（效果结算由关闭分支拦住）
func _set_area_closed(closed: bool) -> void:
	# 区域光环随状态开关；中心图标始终显示，冷却中也能看清构筑物本体
	_aura.visible = not closed
	_center_icon.visible = true

