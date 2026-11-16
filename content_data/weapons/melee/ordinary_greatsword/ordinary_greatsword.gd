extends "res://weapons/melee/melee_weapon.gd"


# ============================================================
# 普通的大剑（武器脚本）
#   每挥砍 ATTACKS_PER_TRIGGER(5) 次触发一次特殊攻击，交替进行：
#     第 5 / 15 / 25… 次（5 的奇数档）⇒ 地裂斩：剑下挥一次，对「半径 = 武器射程」内
#        所有目标造成面板伤害，并留下 300×300 地裂（随射程放大）
#     第 10 / 20 / 30… 次（5 的偶数档）⇒ 旋转：角色与手中的大剑一起自转 SPIN_DURATION 秒
#   旋转期间持续开启武器命中框，并每 SPIN_HIT_RESET_INTERVAL 重置一次命中忽略列表
#   （disable_hitbox 会清空 ignored_objects）⇒ 敌人每隔该间隔可被再次扫中。
#   伤害沿用武器面板同一套结算（暴击 / 近战与护甲缩放 / 击杀信号等）。
# ------------------------------------------------------------
# 实现要点：
#   1) 角色不整体旋转：剑由武器自身 rotation 绕角色中心扫掠，角色左右翻面跟随剑侧
#   2) 旋转期间不调用父类 _physics_process（不瞄准、不开火），结束后还原剑位姿与角色翻面
#   3) 触发计数读 weapon.gd 的 _nb_shots_taken（每次 shoot() +1）
#   4) 圈数：SPIN_DURATION ÷ 当前攻击间隔（攻速越快 → 间隔越短 → 圈数越多）
#   5) 旋转期间剑根移到角色中心、剑身按「武器射程」拉长（覆盖 0~射程 的扫掠半径），
#      命中矩形同步拉长；结束时把位姿/缩放/命中形状全部还原
# ============================================================

# 每多少次挥砍触发一次特殊攻击：count/5 为奇数 ⇒ 地裂斩，偶数 ⇒ 旋转
const ATTACKS_PER_TRIGGER := 5
const SPIN_DURATION := 2.0
const SPIN_HIT_RESET_INTERVAL := 0.5
# 旋转结束前淡出剑影的时长（秒）
const SPIN_SLASH_FADE_TIME := 0.3
# 剑影：6 张 192×192 方形材质按圆周 6 等分（每 60° 一张），弦长 168px、凸起朝外
const SLASH_SECTOR_COUNT := 6
const SLASH_SECTOR_DEGREES := 360.0 / SLASH_SECTOR_COUNT
const SLASH_ARC_CHORD := 168.0
# 剑影长度占剑长（射程）的比例：0.75 ⇒ 弧长 = 0.75R，不超剑
const SLASH_LENGTH_RATIO := 0.75
# 剑影长轴垂直于剑身（整段弧位于剑身外侧、凸起朝外）
const SLASH_BASE_ROTATION := PI * 0.5
# 剑影切向偏移几何（都按射程比例）：画布半边 96/224R、剑身半宽 17/225R（剑贴图 225×75）
const SLASH_CANVAS_HALF_RATIO := 96.0 / 224.0
const SLASH_BLADE_HALF_RATIO := 17.0 / 225.0
# 切向偏移比例：画布半边 0.4286R + 剑身半宽 0.0756R ≈ 0.5041R ⇒ 画布边刚好不压剑身
const SLASH_TANGENT_OFFSET_RATIO := SLASH_CANVAS_HALF_RATIO + SLASH_BLADE_HALF_RATIO
# 剑影径向中心（占射程比例）：0.65 ⇒ 弧弦在 0.65R、弧顶在 0.864R（不超剑尖）
const SLASH_RADIAL_OFFSET_RATIO := 0.65
# 地裂斩：每 5 次挥砍的奇数档触发，剑放大到射程后下挥，对「以角色为圆心、半径 = 射程」内所有目标造成面板伤害并留下地裂
const SLAM_SCENE = preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/weapons/melee/ordinary_greatsword/ordinary_greatsword_slam.tscn")
# 地裂材质 300×300、命中圆基础半径 150（场景内 CircleShape2D）
const SLAM_BASE_RADIUS := 150.0
const SLAM_SMOKE_AMOUNT := 12
const SLAM_SOUND_DB_MOD := -10
# 下挥动画：举剑（同时放大）→ 下挥 → 落地（圆周伤害 + 地裂）→ 收剑
const SLAM_WINDUP_TIME := 0.15
const SLAM_SWEEP_TIME := 0.25
const SLAM_RECOVER_TIME := 0.15
const SLAM_TOTAL_TIME := SLAM_WINDUP_TIME + SLAM_SWEEP_TIME + SLAM_RECOVER_TIME
# 下挥起止角度（-90° 举向正上 → +90° 劈向正下）
const SLAM_POSE_ANGLE_START := -PI * 0.5
const SLAM_POSE_ANGLE_END := PI * 0.5

var _fengliu_spinning := false
var _fengliu_spin_time_left := 0.0
var _fengliu_hit_reset_time_left := 0.0
var _fengliu_spin_angle := 0.0
var _fengliu_last_trigger_shot_count := 0
# 下挥斩状态
var _fengliu_slamming := false
var _fengliu_slam_time := 0.0
var _fengliu_slam_sweep_started := false
var _fengliu_slam_impact_done := false

# 进入旋转前保存的原始位姿 / 缩放 / 命中形状 / 角色翻面符号（结束时还原）
var _fengliu_saved_weapon_position := Vector2.ZERO
var _fengliu_saved_weapon_rotation := 0.0
var _fengliu_saved_sprite_position := Vector2.ZERO
var _fengliu_saved_sprite_scale := Vector2.ONE
var _fengliu_saved_sprite_rotation := 0.0
var _fengliu_saved_hitbox_extents := Vector2.ZERO
var _fengliu_saved_hitbox_collision_position := Vector2.ZERO
var _fengliu_saved_player_sprite_signs := []

# 旋转时贴在剑身外侧的划动特效（6 张 192×192 弧形素材，每转过 60° 换一张）
onready var _spin_slash: Sprite = get_node_or_null("SpinSlash")
export (Array, Texture) var slash_textures = []

var _fengliu_last_slash_segment := -1


# 旋转/下挥期间永不开火（即使父类或其他路径调用 should_shoot）
func should_shoot() -> bool:
	if _fengliu_spinning or _fengliu_slamming:
		return false

	return .should_shoot()


# 旋转/下挥期间拦截任何 shoot()：不挥砍、不累加 _nb_shots_taken
func shoot() -> void:
	if _fengliu_spinning or _fengliu_slamming:
		return

	.shoot()


# 移动时也要保持「剑旋转 + 角色朝剑侧」：
#   玩家移动翻面发生在物理阶段（Unit._physics_process → update_animation），
#   这里在 idle 阶段再覆盖一次，确保移动中同样生效
func _process(delta: float) -> void:
	._process(delta)

	if _fengliu_spinning:
		rotation = _fengliu_spin_angle
		_fengliu_update_player_facing(cos(_fengliu_spin_angle) >= 0.0)
	elif _fengliu_slamming:
		# 物理阶段已推进时间，这里只按当前进度重摆位姿（防止被其它路径改动）
		_fengliu_apply_slam_pose(_fengliu_slam_time)
		_fengliu_update_player_facing(true)


func _physics_process(delta: float) -> void:
	# 旋转中：由本脚本驱动角色与剑，跳过父类的瞄准/开火
	if _fengliu_spinning:
		_fengliu_update_spin(delta)
		return

	# 下挥斩中：同样跳过父类的瞄准/开火
	if _fengliu_slamming:
		_fengliu_update_slam(delta)
		return

	._physics_process(delta)
	_fengliu_check_trigger()


# 触发：挥砍次数达到 ATTACKS_PER_TRIGGER 的倍数（且不是刚触发过的那个计数）
#   5 的奇数档 ⇒ 地裂斩；偶数档 ⇒ 旋转
func _fengliu_check_trigger() -> void:
	if _nb_shots_taken <= 0 or _nb_shots_taken == _fengliu_last_trigger_shot_count:
		return
	if _nb_shots_taken % ATTACKS_PER_TRIGGER != 0:
		return
	# 挥砍动画未结束时不打断（否则收尾的 disable_hitbox 会关掉旋转命中框）
	if _is_shooting:
		return
	if weapon_pos < 0:
		return

	var player = _parent
	if player == null or not is_instance_valid(player) or player.dead:
		return

	_fengliu_last_trigger_shot_count = _nb_shots_taken

	if _fengliu_is_slam_shot(_nb_shots_taken):
		_fengliu_start_slam()
	else:
		_fengliu_start_spin()


# 该挥砍计数是否走“地裂斩”（5 的倍数里的奇数档：5/15/25…）
func _fengliu_is_slam_shot(count: int) -> bool:
	if count <= 0 or count % ATTACKS_PER_TRIGGER != 0:
		return false

	return int(count / ATTACKS_PER_TRIGGER) % 2 == 1


# 进入旋转：保存位姿/角色翻面，剑绕角色中心拉长扫掠，开启命中框
func _fengliu_start_spin() -> void:
	_fengliu_save_pose()
	_fengliu_save_player_facing()
	_fengliu_spin_angle = 0.0
	_fengliu_apply_spin_pose()
	_fengliu_spinning = true
	_fengliu_spin_time_left = SPIN_DURATION
	_fengliu_hit_reset_time_left = SPIN_HIT_RESET_INTERVAL
	enable_hitbox()


# 保存旋转前的武器位姿 / 剑身缩放 / 命中矩形
func _fengliu_save_pose() -> void:
	_fengliu_saved_weapon_position = position
	_fengliu_saved_weapon_rotation = rotation
	_fengliu_saved_sprite_position = sprite.position
	_fengliu_saved_sprite_scale = sprite.scale
	_fengliu_saved_sprite_rotation = sprite.rotation

	var hitbox_collision = _hitbox.get_node_or_null("Collision")
	if hitbox_collision != null and hitbox_collision.shape is RectangleShape2D:
		_fengliu_saved_hitbox_extents = hitbox_collision.shape.extents
		_fengliu_saved_hitbox_collision_position = hitbox_collision.position


# 剑贴图宽 → 横向缩放（把剑身拉长到 radius；旋转与下挥共用）
func _fengliu_get_blade_scale_x(radius: float) -> float:
	var tex_width: float = 225.0
	if sprite.texture != null:
		tex_width = max(1.0, float(sprite.texture.get_width()))

	return max(1.0, radius) / tex_width


# 命中矩形拉长到覆盖 0~radius（形状复制，避免改动共享 sub_resource；旋转与下挥共用）
func _fengliu_stretch_hitbox(radius: float) -> void:
	var safe_radius: float = max(1.0, radius)
	var scale_x: float = _fengliu_get_blade_scale_x(safe_radius)

	var hitbox_collision = _hitbox.get_node_or_null("Collision")
	if hitbox_collision != null and hitbox_collision.shape is RectangleShape2D:
		var shape = hitbox_collision.shape.duplicate()
		shape.extents = Vector2(safe_radius * 0.5 / scale_x, _fengliu_saved_hitbox_extents.y)
		hitbox_collision.shape = shape
		hitbox_collision.position = Vector2.ZERO


# 旋转姿态：剑根贴到角色中心、剑身沿 +X 拉长到「武器射程」，命中矩形同步覆盖 0~射程
func _fengliu_apply_spin_pose() -> void:
	var radius: float = max(1.0, float(current_stats.max_range))
	var scale_x: float = _fengliu_get_blade_scale_x(radius)

	# 剑根在角色中心、朝 +X（由武器自身旋转形成扫掠）
	position = Vector2.ZERO
	rotation = 0.0
	# 剑身从中心伸到 radius（sprite 居中，所以中心点在 radius/2）
	sprite.scale = Vector2(scale_x, 1.0)
	sprite.position = Vector2(radius * 0.5, 0.0)
	sprite.rotation = 0.0

	_fengliu_stretch_hitbox(radius)

	# 划动特效：径向 0.65R 处、画布边刚好不压剑身（凸起朝外），6 张不同弧度素材每 60° 换一张
	if _spin_slash != null:
		_spin_slash.visible = true
		_spin_slash.position = Vector2(radius * SLASH_RADIAL_OFFSET_RATIO, -radius * SLASH_TANGENT_OFFSET_RATIO)
		# 弧长 = 射程 × SLASH_LENGTH_RATIO（不超剑）
		var slash_scale: float = radius * SLASH_LENGTH_RATIO / SLASH_ARC_CHORD
		_spin_slash.scale = Vector2(slash_scale, slash_scale)
		_spin_slash.rotation = SLASH_BASE_ROTATION
		_spin_slash.modulate.a = 1.0

		_fengliu_last_slash_segment = -1
		_fengliu_sync_slash_texture()


# 指定当前剑影贴图（按素材数组循环）
func _fengliu_apply_slash_texture(index: int) -> void:
	if _spin_slash == null or slash_textures.size() == 0:
		return

	_spin_slash.texture = slash_textures[index % slash_textures.size()]


# 每转过 60°（0/60/…/300/360）换成该扇区对应的素材（扇区 0~5 与 6 张一一对应）
func _fengliu_sync_slash_texture() -> void:
	if _spin_slash == null or slash_textures.size() == 0:
		return

	# 加 0.0001° 容差：避免角度正好落在 60° 边界时因浮点误差退回上一段
	var degrees: float = fposmod(rad2deg(_fengliu_spin_angle), 360.0)
	var segment: int = int(floor((degrees + 0.0001) / SLASH_SECTOR_DEGREES)) % SLASH_SECTOR_COUNT
	if segment == _fengliu_last_slash_segment:
		return

	_fengliu_last_slash_segment = segment
	_fengliu_apply_slash_texture(segment % slash_textures.size())


# 还原旋转前的位姿 / 剑身缩放 / 命中矩形
func _fengliu_restore_pose() -> void:
	position = _fengliu_saved_weapon_position
	rotation = _fengliu_saved_weapon_rotation
	sprite.position = _fengliu_saved_sprite_position
	sprite.scale = _fengliu_saved_sprite_scale
	sprite.rotation = _fengliu_saved_sprite_rotation

	var hitbox_collision = _hitbox.get_node_or_null("Collision")
	if hitbox_collision != null and hitbox_collision.shape is RectangleShape2D:
		hitbox_collision.shape.extents = _fengliu_saved_hitbox_extents
		hitbox_collision.position = _fengliu_saved_hitbox_collision_position


# 旋转中：武器绕角色中心旋转 + 角色翻面跟随剑侧 + 周期性重置命中忽略列表
func _fengliu_update_spin(delta: float) -> void:
	var player = _parent
	if player == null or not is_instance_valid(player) or player.dead:
		_fengliu_end_spin()
		return

	_fengliu_spin_angle += _fengliu_get_spin_speed() * delta
	rotation = _fengliu_spin_angle
	# 剑在右半边 ⇒ 角色朝右；剑在左半边 ⇒ 角色朝左
	_fengliu_update_player_facing(cos(_fengliu_spin_angle) >= 0.0)
	# 每转过 60° 换一张剑影材质
	_fengliu_sync_slash_texture()

	_fengliu_hit_reset_time_left -= delta
	if _fengliu_hit_reset_time_left <= 0.0:
		_fengliu_hit_reset_time_left = SPIN_HIT_RESET_INTERVAL
		# disable_hitbox 会清空 ignored_objects，随即可再次扫中同一敌人
		disable_hitbox()
		enable_hitbox()

	_fengliu_spin_time_left -= delta
	if _fengliu_spin_time_left <= 0.0:
		_fengliu_end_spin()
	else:
		_fengliu_update_slash_fade()


# 最后 SPIN_SLASH_FADE_TIME 秒内让剑影线性淡出
func _fengliu_update_slash_fade() -> void:
	if _spin_slash == null:
		return

	_spin_slash.modulate.a = clamp(_fengliu_spin_time_left / max(0.05, SPIN_SLASH_FADE_TIME), 0.0, 1.0)


# 记录角色当前翻面（Animation 各子节点的 scale.x 符号）
func _fengliu_save_player_facing() -> void:
	_fengliu_saved_player_sprite_signs.clear()

	var player = _parent
	if player == null or not is_instance_valid(player):
		return

	var player_sprites = player.get("_sprites")
	if player_sprites == null:
		return

	for player_sprite in player_sprites:
		if player_sprite == null or not is_instance_valid(player_sprite):
			_fengliu_saved_player_sprite_signs.push_back(1.0)
			continue
		_fengliu_saved_player_sprite_signs.push_back(-1.0 if player_sprite.scale.x < 0.0 else 1.0)


# 还原角色翻面
func _fengliu_restore_player_facing() -> void:
	var player = _parent
	if player == null or not is_instance_valid(player):
		return

	var player_sprites = player.get("_sprites")
	if player_sprites == null:
		return

	for i in player_sprites.size():
		var player_sprite = player_sprites[i]
		if player_sprite == null or not is_instance_valid(player_sprite):
			continue
		var saved_sign: float = _fengliu_saved_player_sprite_signs[i] if i < _fengliu_saved_player_sprite_signs.size() else 1.0
		player_sprite.scale.x = saved_sign * abs(player_sprite.scale.x)


# 角色朝右/朝左（Brotato 用 Animation 子节点的 scale.x 符号表示朝向）
func _fengliu_update_player_facing(facing_right: bool) -> void:
	var player = _parent
	if player == null or not is_instance_valid(player):
		return

	var player_sprites = player.get("_sprites")
	if player_sprites == null:
		return

	var sign_x: float = 1.0 if facing_right else -1.0
	for player_sprite in player_sprites:
		if player_sprite == null or not is_instance_valid(player_sprite):
			continue
		player_sprite.scale.x = sign_x * abs(player_sprite.scale.x)


# 旋转期间锁定武器贴图不上下翻转（否则扫到左侧时剑会上下镜像）
func update_sprite_flipv() -> void:
	if _fengliu_spinning:
		sprite.flip_v = false
		return

	.update_sprite_flipv()


# 旋转角速度：圈数 = SPIN_DURATION ÷ 当前攻击间隔 ⇒ 每「一个攻击间隔」正好转 1 圈
func _fengliu_get_spin_speed() -> float:
	var attack_interval: float = 0.0
	if player_index >= 0:
		# 面板冷却：含近战动画时长与玩家攻速加成
		attack_interval = current_stats.get_cooldown_value(player_index, 1.0)

	# 无玩家数据时兜底：按基础冷却估算（不含攻速）
	if attack_interval <= 0.0:
		attack_interval = float(current_stats.cooldown) / 60.0

	return TAU / max(0.05, attack_interval)


# 结束旋转：还原剑的位姿/缩放/命中形状与角色翻面，关闭命中框
func _fengliu_end_spin() -> void:
	_fengliu_spinning = false
	_fengliu_spin_time_left = 0.0

	_fengliu_restore_pose()
	_fengliu_restore_player_facing()
	disable_hitbox()

	# 收起划动特效并复位透明度
	if _spin_slash != null:
		_spin_slash.visible = false
		_spin_slash.modulate.a = 1.0


# 地裂斩入口：保存位姿 → 进入下挥动画（举剑/放大 → 下挥 → 落地伤害+地裂 → 收剑）
func _fengliu_start_slam() -> void:
	var player = _parent
	if player == null or not is_instance_valid(player) or player.dead:
		return

	_fengliu_save_pose()
	_fengliu_save_player_facing()
	_fengliu_slamming = true
	_fengliu_slam_time = 0.0
	_fengliu_slam_sweep_started = false
	_fengliu_slam_impact_done = false
	# 下挥在角色右侧劈下 ⇒ 角色朝右
	_fengliu_update_player_facing(true)
	_fengliu_apply_slam_pose(0.0)


# 下挥进度 → [武器角度, 放大比例 0~1]
func fengliu_get_slam_pose_at(elapsed: float) -> Array:
	var windup_end: float = SLAM_WINDUP_TIME
	var sweep_end: float = SLAM_WINDUP_TIME + SLAM_SWEEP_TIME

	if elapsed <= windup_end:
		var t: float = clamp(elapsed / max(0.001, SLAM_WINDUP_TIME), 0.0, 1.0)
		return [lerp(0.0, SLAM_POSE_ANGLE_START, t), t]

	if elapsed <= sweep_end:
		var t: float = clamp((elapsed - windup_end) / max(0.001, SLAM_SWEEP_TIME), 0.0, 1.0)
		return [lerp(SLAM_POSE_ANGLE_START, SLAM_POSE_ANGLE_END, t), 1.0]

	var t2: float = clamp((elapsed - sweep_end) / max(0.001, SLAM_RECOVER_TIME), 0.0, 1.0)
	return [SLAM_POSE_ANGLE_END, 1.0 - t2]


# 摆放「剑贴角色中心、剑身按射程放大」的下挥姿态（grow: 0=原始缩放 1=放大到射程）
func _fengliu_apply_slam_pose(elapsed: float) -> void:
	var radius: float = max(1.0, float(current_stats.max_range))
	var target_scale: float = _fengliu_get_blade_scale_x(radius)

	var pose: Array = fengliu_get_slam_pose_at(elapsed)
	var grow: float = pose[1]
	var base_scale: float = _fengliu_saved_sprite_scale.x

	position = Vector2.ZERO
	rotation = pose[0]
	sprite.position = Vector2(radius * 0.5, 0.0)
	sprite.rotation = 0.0
	sprite.scale = Vector2(lerp(base_scale, target_scale, grow), _fengliu_saved_sprite_scale.y)


# 下挥推进：举剑 → 下挥（开命中框）→ 落地（关命中框 + 圆周伤害 + 地裂）→ 收剑还原
func _fengliu_update_slam(delta: float) -> void:
	var player = _parent
	if player == null or not is_instance_valid(player) or player.dead:
		_fengliu_end_slam()
		return

	var radius: float = max(1.0, float(current_stats.max_range))
	_fengliu_slam_time += delta

	# 下挥开始：命中矩形拉长并开命中框（刀刃扫过的整段都算命中）
	if not _fengliu_slam_sweep_started and _fengliu_slam_time >= SLAM_WINDUP_TIME:
		_fengliu_slam_sweep_started = true
		_fengliu_stretch_hitbox(radius)
		enable_hitbox()

	# 下挥结束 = 落地：关命中框，结算圆周面板伤害并留下地裂
	if not _fengliu_slam_impact_done and _fengliu_slam_time >= SLAM_WINDUP_TIME + SLAM_SWEEP_TIME:
		_fengliu_slam_impact_done = true
		disable_hitbox()
		_fengliu_spawn_slam_explosion(player, radius)

	_fengliu_apply_slam_pose(_fengliu_slam_time)

	if _fengliu_slam_time >= SLAM_TOTAL_TIME:
		_fengliu_end_slam()


# 收尾：清状态、关命中框、还原位姿与角色朝向
func _fengliu_end_slam() -> void:
	_fengliu_slamming = false
	_fengliu_slam_time = 0.0
	_fengliu_slam_sweep_started = false
	_fengliu_slam_impact_done = false
	disable_hitbox()
	_fengliu_restore_pose()
	_fengliu_restore_player_facing()


func _fengliu_spawn_slam_explosion(player, radius: float) -> void:
	var effect = ExplodingEffect.new()
	effect.explosion_scene = SLAM_SCENE
	# 地裂材质 300×300、命中圆基础半径 150 ⇒ 可见直径 = 2R、命中半径 = R
	effect.scale = radius / SLAM_BASE_RADIUS
	effect.base_smoke_amount = SLAM_SMOKE_AMOUNT
	effect.sound_db_mod = SLAM_SOUND_DB_MOD

	var args = WeaponServiceExplodeArgs.new()
	args.pos = player.global_position
	args.damage = current_stats.damage
	args.scaling_stats = current_stats.scaling_stats
	args.accuracy = current_stats.accuracy
	args.crit_chance = current_stats.crit_chance
	if player_index >= 0:
		args.crit_chance += Utils.get_capped_stat(Keys.stat_crit_chance_hash, player_index) / 100.0
	args.crit_damage = current_stats.crit_damage
	args.from_player_index = player_index
	args.from = self
	args.burning_data = current_stats.burning_data

	var explosion = WeaponService.explode(effect, args)
	if explosion == null or not is_instance_valid(explosion):
		# 兜底：爆炸管线没能给出实例时，自己实例化地裂，保证特效一定出现
		var main_fallback = Utils.get_scene_node()
		if main_fallback == null:
			return
		explosion = SLAM_SCENE.instance()
		explosion.player_index = player_index
		explosion.global_position = args.pos
		explosion.set_damage(args)
		explosion.set_area(effect.scale)
		explosion.set_from(self)
		main_fallback.add_explosion(explosion)
		explosion.start_explosion()

	# 地裂属于地面贴图：从 Explosions 层改挂到 FirePuddles（地板之上、角色之下）
	var main = Utils.get_scene_node()
	var ground_layer = main.get_node_or_null("FirePuddles") if main != null else null
	if ground_layer != null:
		var old_parent = explosion.get_parent()
		if old_parent != null:
			old_parent.remove_child(explosion)
		ground_layer.add_child(explosion)
		explosion.global_position = args.pos

	# 地裂不吃玩家「爆炸透明度」设置；淡出交给场景动画的 self_modulate
	var crack_sprite = explosion.get_node_or_null("Sprite")
	if crack_sprite != null:
		crack_sprite.modulate.a = 1.0
		# 池化复用时清掉上一次淡出残留（动画首帧虽然会在 0s 重置，这里再保险一次）
		crack_sprite.self_modulate = Color(1, 1, 1, 1)

	# 伤害/击杀接回武器（照 unit.gd 与万象天引的接法）
	explosion.connect("hit_something", self, "on_weapon_hit_something", [explosion._hitbox])
	if not explosion.is_connected("killed_something", self, "on_killed_something"):
		explosion.connect("killed_something", self, "on_killed_something", [explosion._hitbox])
