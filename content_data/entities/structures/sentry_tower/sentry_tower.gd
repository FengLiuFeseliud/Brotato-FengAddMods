class_name SentryTower
extends Turret


# 哨戒塔：锁定目标后按 stats.cooldown 的节拍持续用激光结算伤害
#   节拍长度 = WeaponService.apply_structure_attack_speed_effects(stats.cooldown, player_index) 帧 ÷ 60 秒（含建筑攻速）
#   每个节拍造成一次 stats.damage 并记 1 次攻击，累计 close_after_attacks_base + 20% 工程学 次后关闭 close_duration 秒
#   节拍用本类私有计时器（不用基类的 _cooldown：原版炮塔的动画驱动链路会反复重置它）
#   光束本体（continuous_laser）只负责驻留、跟随目标、只打锁定目标
#
# 关闭前基础攻击次数（默认值；实际由效果资源给出）
const CLOSE_AFTER_ATTACKS_BASE: = 5
# 每 1 点工程学增加的攻击次数比例（默认值）
const ENGINEERING_ATTACK_RATE: = 0.2
# 关闭时长（秒，默认值）
const CLOSE_DURATION: = 3.0
# 打满次数后光束的滞留节拍数（显示时长 = N × 当前攻击速度节拍）
const CLOSE_LINGER_BEATS: = 3

onready var _attack_bar: UIProgressBar = $AttackBar

# 锁定中的目标（只在其死亡或超出攻击范围时才切换）
var _locked_target: Node = null
# 当前这束持续激光（塔关闭时收掉）
var _active_beam = null
# 本次开启已结算的攻击次数
var _attacks_done: int = 0
# 本次开启允许的攻击次数
var _attacks_before_close: int = CLOSE_AFTER_ATTACKS_BASE
# 关闭剩余时间（秒），大于 0 表示正在冷却
var _close_time_left: float = 0.0
# 打满次数后光束的滞留剩余秒数（= 一个攻击速度节拍；归零即收束并进入关闭）
var _close_pending_time: float = 0.0
# 距离下一次伤害结算的剩余秒数（本塔自己的节拍，不用基类 _cooldown）
var _tick_time_left: float = 0.0
# 关闭机制参数（来自效果资源，缺失时用常量默认值）
var _close_after_attacks_base: int = CLOSE_AFTER_ATTACKS_BASE
var _engineering_attack_rate: float = ENGINEERING_ATTACK_RATE
var _close_duration: float = CLOSE_DURATION


# 生成时读取关闭机制参数并复位状态
func set_data(data: Resource) -> void:
	# 先走炮塔基类的数据初始化（算好 stats、追踪键与诅咒光效）
	.set_data(data)
	# 关闭机制参数来自效果资源，缺失时用默认值
	var base_attacks = data.get("close_after_attacks_base") if data != null else null
	_close_after_attacks_base = int(base_attacks) if base_attacks != null else CLOSE_AFTER_ATTACKS_BASE
	var attack_rate = data.get("engineering_attack_rate") if data != null else null
	_engineering_attack_rate = float(attack_rate) if attack_rate != null else ENGINEERING_ATTACK_RATE
	var duration = data.get("close_duration") if data != null else null
	_close_duration = float(duration) if duration != null else CLOSE_DURATION
	# 关闭阈值与状态复位
	var engineering: float = Utils.get_stat(Keys.stat_engineering_hash, player_index)
	_attacks_before_close = max(1, _close_after_attacks_base + int(engineering * _engineering_attack_rate))
	_attacks_done = 0
	_close_time_left = 0.0
	_close_pending_time = 0.0
	_tick_time_left = 0.0
	_locked_target = null
	_active_beam = null


# 关掉原版炮塔的动画驱动开火：光束只由本类按 stats.cooldown 的节拍发射
func should_shoot() -> bool:
	return false


# 原版由 shoot 动画的方法轨调用本方法发射，本塔不用这套
func shoot() -> void:
	pass


# 原版会在 shoot 动画结束时重置 _cooldown（与 close_after_attacks 联动），本塔只把动画切回 idle
func _on_AnimationPlayer_animation_finished(_anim_name: String) -> void:
	# 原版会在这里把 _cooldown 重置成随机冷却，本塔只用它把动画切回 idle
	if not dead and _animation_player != null:
		_animation_player.play("idle")


# 开火循环：锁定 → 保证有一束持续激光并跟随目标 → 每 stats.cooldown 结算一次伤害并计一次攻击
func _physics_process(delta: float) -> void:
	if dead or stats == null:
		return

	# 剩余攻击次数条随状态刷新
	_update_attack_bar()

	# 关闭期间：只倒计时，不开火（光束由关闭流程收掉）
	if _close_time_left > 0.0:
		_close_time_left -= delta
		if _close_time_left <= 0.0:
			_tick_time_left = 0.0
			_locked_target = null
		return

	# 打满次数：让光束滞留一个攻击速度节拍后再收束，然后进入关闭
	if _close_pending_time > 0.0:
		_close_pending_time -= delta
		if _close_pending_time <= 0.0:
			_close_beam()
			_close_time_left = _close_duration
		return

	# 目标锁定：仅当目标无效 / 死亡 / 超出攻击范围时才切换
	_update_locked_target()
	_current_target = _build_current_target()
	if _locked_target == null:
		_close_beam()
		return

	# 存活的光束每帧跟上锁定目标（光束不存在时该调用自己 no-op）
	_sync_beam_target()

	_tick_time_left -= delta
	if _tick_time_left > 0.0:
		return

	# 到达节拍：光束不存在就现在重建（重建前已等过一整拍），随后立刻结算这一次伤害
	if not _ensure_beam():
		return

	# 重触发由物理进入结算，落在下一帧（见 continuous_laser.tick_damage）
	_active_beam.tick_damage()

	# 打出光束的这一拍播放攻击动画（动画方法轨会调 shoot()，而本塔的 shoot() 是空实现，不会触发原版发射）
	if _animation_player != null:
		_animation_player.playback_speed = _shooting_speed
		_animation_player.play("shoot")

	_attacks_done += 1
	_tick_time_left = _get_damage_interval()
	if _attacks_done >= _attacks_before_close:
		_attacks_done = 0
		# 滞留 N 个攻击速度节拍后再收束
		_close_pending_time = _get_damage_interval() * float(CLOSE_LINGER_BEATS)


# 一个伤害节拍的秒数（stats.cooldown 经建筑攻速换算；下限沿用原版 MIN_COOLDOWN = 2 帧）
func _get_damage_interval() -> float:
	# 原版 _cooldown -= 60 * delta ⇒ cooldown 帧数 ÷ 60 即 delta-time 秒数
	var frames: float = max(2.0, float(_get_max_cooldown()))
	return frames / 60.0


# 让存活光束即时换瞄准（换目标不打断光束、不产生空档）
func _sync_beam_target() -> void:
	# 光束缺失或已经指着同一个目标时不动
	if _active_beam == null or not is_instance_valid(_active_beam):
		return

	if _active_beam.target == _locked_target:
		return

	_active_beam.target = _locked_target
	_active_beam.snap_to_target()

# 保证有一束持续激光（缺失时按原版发射链路新建），返回是否可用
func _ensure_beam() -> bool:
	# 已有光束就直接沿用（目标同步见 _sync_beam_target）
	if _active_beam != null and is_instance_valid(_active_beam):
		return true

	# 取不到目标就不开火
	if _current_target.size() == 0 or not is_instance_valid(_current_target[0]):
		return false

	_next_proj_rotation = (_current_target[0].global_position - global_position).angle()
	for _i in stats.nb_projectiles:
		var beam = _spawn_projectile(_muzzle.global_position)
		if beam != null:
			beam.target = _locked_target
			beam.snap_to_target()
			_active_beam = beam
			return true

	return false


# 收掉当前光束（塔关闭 / 失去目标时调用）
func _close_beam() -> void:
	# 走原版 stop() 让它回池，随后清空引用
	if _active_beam != null and is_instance_valid(_active_beam):
		_active_beam.stop()
	_active_beam = null


# 光束自行消失（目标死亡等）时清掉引用，下一帧由 _ensure_beam 重建
func on_beam_stopped(beam) -> void:
	# 只清掉「就是当前这束」的引用，避免误清刚建好的新光束
	if _active_beam == beam:
		_active_beam = null


# 组装原版要用的 _current_target（[目标, 距离]）
func _build_current_target() -> Array:
	# 无锁定目标时给原版一个空数组
	if _locked_target == null:
		return []

	return [_locked_target, global_position.distance_to(_locked_target.global_position)]


# 锁定目标：目标仍有效且在射程内就保持不动（只有死亡 / 超出范围才切换）
func _update_locked_target() -> void:
	if _locked_target != null and is_instance_valid(_locked_target) and not _locked_target.dead:
		var dist: float = global_position.distance_to(_locked_target.global_position)
		if dist >= float(stats.min_range) and dist <= float(stats.max_range):
			return

	# 重新选最远的可打目标（跳过已死亡 / 无效 / 被魅惑的）
	# 换目标沿用当前节拍（节拍已按建筑攻速 + 中继器换算），不另起延迟
	# 光束由每帧的 _sync_beam_target 即时换瞄准，不打断、不产生空档
	_locked_target = _get_farthest_alive_target()


# 取最远的可打目标（区域内、存活、未被魅惑、且在 min_range 之外）
func _get_farthest_alive_target():
	var best = null
	var best_dist: float = 0.0
	# 遍历区域内目标，取最远的存活者
	for enemy in _targets_in_range:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		# 中性单位（矿石/村民等）没有魅惑接口，按「未被魅惑」处理，避免 Invalid call 报错
		if enemy.has_method("get_charmed_by_player_index") and enemy.get_charmed_by_player_index() >= 0:
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < float(stats.min_range):
			continue
		if best == null or dist > best_dist:
			best = enemy
			best_dist = dist

	return best


# 剩余攻击次数条
func _update_attack_bar() -> void:
	if _attack_bar == null:
		return

	# 关闭期间与滞留期间都显示空条：这两段都已经没有剩余攻击次数（_attacks_done 已在打满那拍复位）
	var total: float = float(max(1, _attacks_before_close))
	var closing: bool = _close_time_left > 0.0 or _close_pending_time > 0.0
	var remaining: float = 0.0 if closing else max(0.0, total - float(_attacks_done))
	_attack_bar.value = remaining / total * 100.0
