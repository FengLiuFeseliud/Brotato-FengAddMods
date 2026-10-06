extends "res://projectiles/bullet_particle_accelerator/particle_accelerator_projectile.gd"


# --------------------------------------------------------------------
# 持续激光弹体（哨戒塔用）
# 以 mod 的 projectiles/suns（＝原版粒子加速器弹体）的效果为底：驻留、铺满射程的光束。
# 与 suns 的差别：
#   1) 不去世：停掉 fire 动画并把各容器缩放固定为满尺寸，生命周期由哨戒塔掌控；
#   2) 路径上全打：重叠到的所有目标各自走原版受击链路，target 只用于瞄准；
#      剩余贯穿数 / 每穿递减 / 贯穿耗尽收束由原版 PlayerProjectile 处理；
#   3) 随目标移动：每帧贴到枪口、转向 target，身体贴图与末端装饰一起缩到目标处；
#   4) 目标死亡 / 失效 / 塔被打掉 ⇒ 自行 stop()，并通知塔清引用（塔下一帧重建）；
#   5) 结算节拍不在本类：何时造成一次伤害由哨戒塔按 stats.cooldown 调 tick_damage()。
# 伤害仍由原版链路结算（受击单位自己调 hitbox.hit_something），本脚本不直接造成伤害。
# --------------------------------------------------------------------


# 本束光锁定的目标（由哨戒塔在发射后赋值）
var target: Node = null

# 本帧是否要重新启用命中判定（disable 的下一帧再 enable）
var _enable_hitbox_next_frame: bool = false
# 塔刚请求过一次结算
var _pending_tick: bool = false
# 是否已经收束过（避免重复回池 / 重复通知）
var _stopped: bool = false


# 发射：走原版粒子加速器的铺满射程布局，然后固定成常驻满尺寸光束
func shoot() -> void:
	.shoot()
	# 驻留：不再前进，停在枪口
	velocity = Vector2.ZERO
	# 停掉 fire 动画（否则它的方法轨会在 0.4s 时 stop() 掉光束）
	if _animation_player != null:
		_animation_player.stop()
	# 手动把动画负责的三处缩放固定为满尺寸
	if contents != null:
		contents.scale = Vector2.ONE
	if start_container != null:
		start_container.scale = Vector2.ONE
	if end_container != null:
		end_container.scale = Vector2.ONE
	# 过滤非目标需要自己检测重叠，原版 suns 场景里这块是关着的
	_hitbox.monitoring = true
	# 计时改由本类接管（见 _set_time_until_max_range）
	_set_time_until_max_range()
	_enable_hitbox_next_frame = false
	_pending_tick = false
	_stopped = false
	# 光束创建时不结算：形状先离开物理空间，等塔的第一次 tick_damage 再触发（避免白送一发）
	_hitbox.disable()


# 覆盖：不按 max_range / projectile_speed 计时（速度可能为 0，原版会除以它）
func _set_time_until_max_range() -> void:
	_time_until_max_range = 1000000.0


# 收束 / 回池时先通知发射者：塔必须知道这束光已经没了，否则会一直沿用死引用（换目标后不再重建）
# 注意基类 stop() 在菜单环境可能因池子拿不到场景节点而中断，所以通知必须放在它前面
func stop() -> void:
	# 重复调用直接忽略（回池后可能还会被再调一次）
	if _stopped:
		return

	_stopped = true
	var source = _hitbox.from if _hitbox != null else null
	if source != null and is_instance_valid(source) and source.has_method("on_beam_stopped"):
		source.on_beam_stopped(self)
	.stop()


# 每帧：跟随目标 / 目标或塔没了就消失 / 维护「只打锁定目标」的忽略名单 / 落地塔请求的结算
func _physics_process(delta: float) -> void:
	._physics_process(delta)

	if _hitbox == null:
		return

	# 目标或发射者消失 ⇒ 光束消失
	if not _can_stay():
		stop()
		return

	_follow_target()

	# 上一帧关掉的命中判定在这里恢复 ⇒ 原版重叠事件重新触发（这一刻只结算锁定目标）
	if _enable_hitbox_next_frame:
		_enable_hitbox_next_frame = false
		_hitbox.enable()

	# 塔请求的结算：让形状离开物理空间一帧（下一帧再 enable 重新触发）
	# 路径上重叠到的所有目标都会各自走原版受击链路；“剩余贯穿数 / 每穿递减 / 贯穿耗尽收束”由原版 PlayerProjectile 处理
	if _pending_tick:
		# 必须先清掉 ignored_objects：原版 PlayerProjectile 命中后会把对象 append 进去（player_projectile.gd:107），
		# 不清的话下一拍会被受击方 unit.gd:537 的 has(self) 挡掉 ⇒ 表现成「只掉一次血、不能持续伤害」
		_pending_tick = false
		_hitbox.ignored_objects.clear()
		_hitbox.disable()
		_enable_hitbox_next_frame = true


# 请求一次伤害结算（由哨戒塔按 stats.cooldown 的节拍调用）
func tick_damage() -> void:
	# 只做标记，真正的清名单 / disable / enable 放在本类 _physics_process（塔调用时帧序不定）
	_pending_tick = true


# 立刻贴到枪口并转向目标（塔发射 / 换目标时调用）
func snap_to_target() -> void:
	# 目标或塔已失效时什么都不做（下一帧 _physics_process 会自行收束）
	if not _can_stay():
		return

	_follow_target()


# 光束是否还能留在场上（目标存活 + 发射者存活）
func _can_stay() -> bool:
	# 目标引用被释放（换关 / 回池）或死亡都算失效
	if target == null or not is_instance_valid(target) or target.dead:
		return false

	# 塔被打掉后光束不该继续留在场上
	var source = _hitbox.from if _hitbox != null else null
	if source != null and (not is_instance_valid(source) or source.dead):
		return false

	return true


# 跟随：贴到枪口、转向目标；身体贴图按到目标的距离缩短，末端装饰跟着回退
func _follow_target() -> void:
	var from: Vector2 = spawn_position
	# 瞄准点 = 怪的原点 + Hurtbox 判定框中心偏移（否则光束会斜着打在怪的下缘/脚下）
	var to: Vector2 = target.global_position + _aim_offset()
	global_position = from
	rotation = (to - from).angle()

	# 起点装饰占前 S、末端装饰占后 C，宽度固定 ⇒ 贴脸时把整条光束等比缩小，
	# 这样「末端装饰的右边缘」在任何距离都正好落在目标上
	# Hitbox 保持原版满射程（伤害判定不跟着缩短，贴脸目标也能结算）
	if _sprite != null and _sprite.texture != null and _weapon_stats != null and float(_weapon_stats.max_range) > 0.0:
		var sprite_w: float = float(_sprite.texture.get_width())
		var cap_w: float = _end_cap_width()
		var dist: float = from.distance_to(to)
		var cap_scale: float = clamp(dist / max(1.0, sprite_w + cap_w * 2.0), 0.05, 1.0)
		var body_start: float = cap_scale * sprite_w
		var body_len: float = max(0.0, dist - cap_scale * (sprite_w + cap_w))
		# 三段首尾相接：起点装饰 [0, cs*S] → 身体 [cs*S, cs*S+len] → 末端装饰 [.., dist]
		if contents != null:
			contents.position.x = body_start
		_sprite.scale.x = max(0.01, body_len / sprite_w)
		if end_container != null:
			end_container.position.x = body_start + body_len
			end_container.scale.x = cap_scale
		if start_container != null:
			start_container.scale.x = cap_scale


# 末端装饰的贴图宽度（用于把它的右边缘对齐到目标）
func _end_cap_width() -> float:
	# 容器缺失时按 0 处理（退化成只对齐身体）
	if end_container == null:
		return 0.0

	for child in end_container.get_children():
		if child is Sprite and child.texture != null:
			return float(child.texture.get_width())

	return 0.0

# 瞄准点的相对偏移：怪的 Hurtbox 判定框中心（Hurtbox 节点位置 + 其 CollisionShape 位置）
# 例：enemy.tscn 的 Hurtbox 在 (0,-16)、其 Collision 在 (0,+7) ⇒ 偏移 (0,-9)
func _aim_offset() -> Vector2:
	# 目标无效或没有 Hurtbox 时不偏移
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO

	# 取受击判定所在节点
	var hurtbox = target.get_node_or_null("Hurtbox")
	if hurtbox == null:
		return Vector2.ZERO

	# 判定框中心 = Hurtbox 位置 + 其形状节点的位置
	var offset: Vector2 = hurtbox.position
	for child in hurtbox.get_children():
		if child is CollisionShape2D:
			offset += child.position
			break

	return offset
