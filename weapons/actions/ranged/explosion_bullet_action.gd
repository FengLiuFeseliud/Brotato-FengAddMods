extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/ranged/ranged_action.gd"


# ============================================================
# 远程动作：爆炸子弹
#   每射击 trigger_count 次后，把下一次普通射击替换为一发爆炸子弹：
#   武器原攻击被取消，由本动作生成子弹，命中后只结算爆炸伤害。
#   子弹场景、爆炸效果与伤害比例由 .tres 提供；伤害默认取面板伤害。
# ------------------------------------------------------------
# 可配置参数：
#   bullet_scene               爆炸子弹场景（为空沿用武器自带子弹）
#   nb_projectiles             每次发射的爆炸子弹基础数（会叠加宿主额外弹丸，含建造者炮塔等级弹丸）
#   bullet_spread              额外散布（弧度）
#   explosion_effects          按武器阶取用的爆炸效果列表（ExplodingEffect .tres）
#   explosion_damage_percent   爆炸伤害占面板伤害百分比（100 = 面板伤害）
#   play_shoot_sound           是否播放武器射击音效
# ============================================================

export(PackedScene) var bullet_scene
export(int) var nb_projectiles = 1
export(float) var bullet_spread = 0.0
export(Array, Resource) var explosion_effects = []
export(float) var explosion_damage_percent = 100.0
export(bool) var play_shoot_sound = true

var _fengliu_fired := false
var _fengliu_warned_missing_explosion := false

const EXPLOSION_EFFECT_META := "fengliu_explosion_bullet_effect"


func fengliu_start() -> void:
	.fengliu_start()
	_fengliu_fired = false


# 激活期间且尚未发射时接管下一次开火
func fengliu_should_take_over_shoot() -> bool:
	return _fengliu_active and not _fengliu_fired


# 武器提示文本参数：普通射击间隔、爆炸伤害百分比
func get_args(_player_index: int = -1) -> Array:
	var every: int = trigger_interval if trigger_interval > 0 else trigger_count
	return [str(every), str(round(explosion_damage_percent))]


# 按武器阶取对应的爆炸效果；列表为空或资源无效时返回 null
func _fengliu_get_explosion_effect():
	if explosion_effects.empty():
		return null

	var index: int = clamp(fengliu_get_host_tier(), 0, explosion_effects.size() - 1)
	var effect = explosion_effects[index]
	if effect == null or not (effect is ExplodingEffect):
		return null

	var exploding_effect = effect as ExplodingEffect
	if exploding_effect == null or exploding_effect.explosion_scene == null:
		return null

	return exploding_effect


func _fengliu_get_projectile_count(host_stats, player_index: int) -> int:
	var player_projectiles: int = 0
	if player_index >= 0:
		player_projectiles = max(0, int(RunData.get_player_effect(Keys.projectiles_hash, player_index)))

	if host_stats == null or not ("nb_projectiles" in host_stats):
		return int(max(1, nb_projectiles + player_projectiles))

	# 宿主总弹丸数已含玩家额外弹丸；减去宿主基础弹丸后即为宿主额外弹丸。
	# 建造者炮塔的等级弹丸就在这部分里，动作基础 nb_projectiles 仍然保留。
	var host_total_projectiles: int = int(host_stats.nb_projectiles)
	var host_base_projectiles: int = fengliu_get_host_base_projectiles()
	var host_extra_projectiles: int = int(max(0, host_total_projectiles - host_base_projectiles))
	return int(max(1, nb_projectiles + host_extra_projectiles))


func fengliu_take_over_shoot() -> void:
	if _fengliu_fired:
		return
	_fengliu_fired = true

	var host_node = fengliu_get_host_from_node()
	if host_node == null or not is_instance_valid(host_node):
		return

	var host_stats = fengliu_get_host_action_stats()
	if host_stats == null:
		return

	# 爆炸效果缺失时不生成子弹，避免命中空场景报错
	var explosion_effect = _fengliu_get_explosion_effect()
	if explosion_effect == null:
		if not _fengliu_warned_missing_explosion:
			_fengliu_warned_missing_explosion = true
			push_warning("explosion_bullet_action: explosion_effects is empty or invalid")
		return

	var player_index: int = fengliu_get_host_player_index()
	var projectile_count: int = _fengliu_get_projectile_count(host_stats, player_index)
	# 复制面板属性，只替换子弹场景、弹丸数与伤害
	var projectile_stats = host_stats.duplicate()
	if bullet_scene != null:
		projectile_stats.projectile_scene = bullet_scene
		
	projectile_stats.nb_projectiles = projectile_count
	projectile_stats.damage = max(1, int(round(float(host_stats.damage) * explosion_damage_percent / 100.0)))

	# 命中时由本动作的命中钩子生成爆炸；效果对象随炮弹携带
	var spawn_args = WeaponServiceSpawnProjectileArgs.new()
	spawn_args.effects = fengliu_get_host_effects().duplicate()
	spawn_args.effects.push_back(explosion_effect)
	spawn_args.from_player_index = player_index
	spawn_args.damage_tracking_key_hash = fengliu_get_host_damage_tracking_key()

	# 同一轮射击共用攻击 ID，避免命中统计重复
	var attack_id: int = fengliu_get_host_attack_id()
	var accuracy: float = clamp(float(projectile_stats.accuracy), 0.0, 1.0)
	for i in projectile_count:
		var spread: float = rand_range(-1.0 + accuracy, 1.0 - accuracy) + rand_range(-bullet_spread, bullet_spread)
		var direction: float = fengliu_get_host_shoot_rotation() + spread
		spawn_args.knockback_direction = Vector2(cos(direction), sin(direction))

		var projectile = WeaponService.spawn_projectile(
			fengliu_get_host_muzzle_position(),
			projectile_stats,
			direction,
			host_node,
			spawn_args
		)
		if not is_instance_valid(projectile):
			continue

		projectile.set_meta(EXPLOSION_EFFECT_META, explosion_effect)
		var projectile_hitbox = projectile.get("_hitbox")
		if projectile_hitbox != null and attack_id >= 0:
			projectile_hitbox.player_attack_id = attack_id

		fengliu_notify_host_projectile_shot(projectile)

	# 接管开火绕过了武器射击行为，音效在这里补上
	var shooting_sounds = host_stats.shooting_sounds
	if play_shoot_sound and shooting_sounds != null and shooting_sounds.size() > 0:
		SoundManager.play(
			Utils.get_rand_element(shooting_sounds),
			host_stats.sound_db_mod,
			0.2
		)


# 炮弹命中后生成真正的爆炸；直接命中伤害仍由投射物结算
func fengliu_on_projectile_hit(thing_hit, _damage_dealt, projectile) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if not projectile.has_meta(EXPLOSION_EFFECT_META):
		return

	var exploding_effect = projectile.get_meta(EXPLOSION_EFFECT_META)
	if exploding_effect == null or not (exploding_effect is ExplodingEffect):
		return

	var hitbox = projectile.get("_hitbox")
	if hitbox == null or not is_instance_valid(hitbox):
		return

	var args = WeaponServiceExplodeArgs.new()
	args.pos = thing_hit.global_position if thing_hit != null and "global_position" in thing_hit else projectile.global_position
	args.damage = int(hitbox.damage)
	args.scaling_stats = hitbox.scaling_stats
	args.accuracy = hitbox.accuracy
	args.crit_chance = hitbox.crit_chance
	args.crit_damage = hitbox.crit_damage
	args.burning_data = hitbox.burning_data
	args.from_player_index = fengliu_get_host_player_index()
	args.is_healing = hitbox.is_healing
	args.damage_tracking_key_hash = fengliu_get_host_damage_tracking_key()
	args.from = fengliu_get_host_from_node()
	args.ignored_objects = [thing_hit] if thing_hit != null else []

	var explosion = WeaponService.explode(exploding_effect, args)
	if explosion == null or not is_instance_valid(explosion):
		return

	var host_node = args.from
	if host_node == null or not is_instance_valid(host_node):
		return

	var explosion_hitbox = explosion.get("_hitbox")
	if explosion_hitbox == null:
		return

	if host_node.has_method("on_weapon_hit_something") and not explosion.is_connected("hit_something", host_node, "on_weapon_hit_something"):
		var _hit_error = explosion.connect("hit_something", host_node, "on_weapon_hit_something", [explosion_hitbox])
	if host_node.has_method("on_killed_something") and not explosion.is_connected("killed_something", host_node, "on_killed_something"):
		var _kill_error = explosion.connect("killed_something", host_node, "on_killed_something", [explosion_hitbox])


func fengliu_is_finished() -> bool:
	return not _fengliu_active
