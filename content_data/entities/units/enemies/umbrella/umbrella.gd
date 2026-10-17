extends Enemy

# 伞：自身不强攻，靠 BoostZone 周期性强化范围内的小怪（深紫光环＝真实判定范围，见 _fengliu_sync_aura_scale）；
# 圈内小怪全部强化（每只只强化一次、永久生效），数量上限 0 = 不限（见 _on_BoostTimer_timeout）
# 移动用 stay_in_range 与玩家保持约 110，而增益圈半径 170 大于该距离，所以贴着玩家的小怪同样会被强化
export (Resource) var boost_sound
export (int) var nb_entities_boosted_at_once = 0
export (float) var boost_cooldown = 1.0
export (int) var hp_boost = 200
export (int) var damage_boost = 50
export (int) var speed_boost = 50

# aura_effect.png 为 250x250，贴图自身半径 125
const AURA_TEXTURE_RADIUS: = 125.0

var entities_in_zone: = []

onready var _boost_zone: Area2D = $"%BoostZone"
onready var _boost_collision: CollisionShape2D = $"%BoostCollision"
onready var _boost_timer: Timer = $"%BoostTimer"
onready var _aura: Sprite = $"BoostZone/Aura"

var _boost_args: = BoostArgs.new()


func _ready() -> void :
	# 先跑 Enemy 的 _ready（攻击行为 / hitbox / 动画初始化都在里面，不能漏）
	._ready()

	# 可视光环跟着判定半径走
	_fengliu_sync_aura_scale()


# 可视范围＝判定范围：只改 BoostCollision 一处，光环自动缩放
func _fengliu_sync_aura_scale() -> void :
	if _aura == null or _boost_collision == null:
		return

	# 贴图半径 125 ⇒ 缩放系数 = 判定半径 / 125
	var radius: float = _boost_collision.shape.radius
	_aura.scale = Vector2(radius / AURA_TEXTURE_RADIUS, radius / AURA_TEXTURE_RADIUS)


# 进入增益圈的单位先记账（只收可被强化的小怪，玩家与构筑物不算）
func _on_BoostZone_body_entered(body: Node) -> void :
	# 只登记「可被强化的小怪」；玩家 / 构筑物 / 已死状态一律忽略
	if not dead and body is Enemy and body.can_be_boosted:
		entities_in_zone.push_back(body)


# 离开增益圈就从账上划掉
func _on_BoostZone_body_exited(body: Node) -> void :
	entities_in_zone.erase(body)


# 冷却到点：把圈内「还没被强化过」的小怪全部强化（上限 > 0 时最多 N 只；强化持续到该小怪回池）
func _on_BoostTimer_timeout() -> void :
	var nb_boosted = 0
	entities_in_zone.shuffle()
	for entity in entities_in_zone:
		# 失效目标或非小怪直接跳过
		if not is_instance_valid(entity) or not (entity is Enemy):
			continue
		if not entity.can_be_boosted or entity.is_boosted:
			continue

		# 小怪强化：生命 / 伤害 / 速度（百分比），并带描边提示
		_boost_args.range_boost = 0
		_boost_args.attack_speed_boost = 0
		_boost_args.hp_boost = hp_boost
		_boost_args.damage_boost = damage_boost
		_boost_args.speed_boost = speed_boost
		entity.boost(_boost_args)
		entity.emit_signal("stats_boosted", entity)

		nb_boosted += 1
		if nb_entities_boosted_at_once > 0 and nb_boosted >= nb_entities_boosted_at_once:
			break

	if nb_boosted > 0:
		emit_signal("stats_boosted", self)
		SoundManager2D.play(boost_sound, global_position, 0.0, 0.2)

	_boost_timer.wait_time = boost_cooldown


func respawn() -> void :
	# 复活时重新开启增益圈（回池时会被关掉）
	.respawn()
	_boost_collision.set_deferred("disabled", false)


func die(args: = Utils.default_die_args) -> void :
	# 死亡 / 离场时关掉增益圈并清账，避免强化已不存在的单位
	.die(args)
	_boost_collision.set_deferred("disabled", true)
	entities_in_zone.clear()
