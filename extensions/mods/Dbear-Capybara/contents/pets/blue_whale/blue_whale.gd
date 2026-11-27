extends "res://mods-unpacked/Dbear-Capybara/contents/pets/blue_whale/blue_whale.gd"


# ============================================================
# Capybara 蓝鲸兼容层（FengAddMods）
# 路径约定：extensions/mods/<mod名>/<原mod路径>
#
# 保留蓝鲸对本 mod 构筑物的环绕/拖动，并在移动前做存活/初始化/脚本检查；
# 重写 refresh/collect 的遍历，避免基类直接访问已失效对象。
# ============================================================

const FENGLIU_WHALE_ACTIONS_META := "fengliu_whale_action_snapshot"

const ACTION_SCHEDULER = preload("res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/action_scheduler.gd")


# 动作宿主：缓存源武器 effects/tier，并代理当前蓝鲸射击上下文。
class FengliuWhaleActionHost:
	extends Reference

	var effects: Array = []
	var player_index: int = -1
	var tier: int = 0
	var source_weapon = null
	var whale = null
	var scheduler = null
	var shot_stats = null
	var shot_rotation: float = 0.0
	var muzzle_position: Vector2 = Vector2.ZERO

	func setup(source_weapon_ref, source_player_index: int, source_whale) -> void:
		player_index = source_player_index
		source_weapon = source_weapon_ref
		whale = source_whale
		if source_weapon == null or not is_instance_valid(source_weapon):
			return
		var source_effects = source_weapon.get("effects")
		if source_effects is Array:
			effects = source_effects.duplicate()
		tier = int(source_weapon.tier)

	func set_shot_context(stats, origin: Vector2, rotation: float) -> void:
		shot_stats = stats.duplicate() if stats != null else null
		muzzle_position = origin
		shot_rotation = rotation

	func fengliu_get_action_tier() -> int:
		return tier

	func fengliu_uses_custom_projectile_forms() -> bool:
		return false

	func fengliu_get_action_stats():
		return shot_stats

	func fengliu_get_action_base_projectiles() -> int:
		if source_weapon != null and is_instance_valid(source_weapon):
			var source_stats = source_weapon.get("stats")
			if source_stats != null and "nb_projectiles" in source_stats:
				return int(max(0, int(source_stats.nb_projectiles)))
		return 0

	func fengliu_get_action_muzzle_position() -> Vector2:
		return muzzle_position

	func fengliu_get_action_shoot_rotation() -> float:
		return shot_rotation

	func fengliu_get_action_attack_id() -> int:
		return -1

	func fengliu_get_action_damage_tracking_key() -> int:
		if whale != null and is_instance_valid(whale):
			var value = whale.get("capybara_gold_tracking_key_hash")
			if value != null:
				return int(value)
		return Keys.empty_hash

	func fengliu_get_action_from_node():
		if whale != null and is_instance_valid(whale):
			return whale
		return source_weapon

	func fengliu_on_action_projectile_shot(projectile) -> void:
		if whale != null and is_instance_valid(whale) and whale.has_method("_fengliu_attach_whale_action_projectile"):
			whale._fengliu_attach_whale_action_projectile(projectile, scheduler)


var _fengliu_whale_schedulers: Array = []
var _fengliu_action_signature: String = ""
var _fengliu_whale_shot_origin: Vector2 = Vector2.ZERO
var _fengliu_whale_shot_rotation: float = 0.0


func _fengliu_can_orbit(structure) -> bool:
	if structure == null or not is_instance_valid(structure):
		return false
	if structure.is_queued_for_deletion() or not structure.is_inside_tree():
		return false
	if not ("dead" in structure) or structure.dead:
		return false
	if "_pending_die" in structure and structure._pending_die:
		return false
	if "player_index" in structure and structure.player_index != player_index:
		return false
	if "stats" in structure and structure.stats == null:
		return false
	var script = structure.get_script()
	if script == null or script.resource_path == "":
		return false
	if structure.has_method("fengliu_capybara_can_orbit") and not structure.fengliu_capybara_can_orbit():
		return false
	return true


func _capybara_move_structure_in_orbit(capybara_structure: Structure, capybara_structure_id: int, delta: float) -> void:
	if not _fengliu_can_orbit(capybara_structure):
		return
	._capybara_move_structure_in_orbit(capybara_structure, capybara_structure_id, delta)


func _capybara_refresh_orbit_structures() -> void:
	capybara_orbit_structures.clear()
	if not capybara_orbit_authoritative:
		capybara_orbit_states.clear()
		return
	var spawner = _entity_spawner_ref
	if spawner == null or not is_instance_valid(spawner):
		capybara_orbit_states.clear()
		return
	var active = {}
	for structure in spawner.structures:
		if not _fengliu_can_orbit(structure):
			continue
		var structure_id = structure.get_instance_id()
		capybara_orbit_structures.append(structure)
		active[structure_id] = true
	for structure_id in capybara_orbit_states.keys():
		if not active.has(structure_id):
			capybara_orbit_states.erase(structure_id)


func _capybara_collect_turret_effects() -> void:
	capybara_turret_effects.clear()
	for item in ItemService.items:
		if not is_instance_valid(item) or not (item is ItemData) or not item.can_be_looted:
			continue
		var effects = item.get("effects")
		if effects == null or not (effects is Array):
			continue
		for effect in effects:
			if not is_instance_valid(effect) or not (effect is TurretEffect):
				continue
			if effect.scene == null or effect.stats == null:
				continue
			capybara_turret_effects.append(effect)


# 开火前同步被复制武器的动作（每把武器实例各一份，不做 weapon_id 去重）
func _capybara_shoot(capybara_target: Enemy) -> void:
	_fengliu_sync_whale_actions(_capybara_get_weapons_for_projectile_effects())
	_fengliu_prepare_whale_shot_context(capybara_target)

	var takeover_pairs = _fengliu_get_takeover_pairs()
	if not takeover_pairs.empty():
		_fengliu_play_whale_fire_feedback()
		for pair in takeover_pairs:
			var action = pair["action"]
			action.fengliu_take_over_shoot()

		# 动作仍激活时统计：count_as_normal_attack=false 的接管不推进普通计数
		_fengliu_register_whale_normal_attack()
		for pair in takeover_pairs:
			var entry = pair["entry"]
			entry["scheduler"].finish_takeover(pair["action"])
		_fengliu_check_whale_triggers()
		return

	._capybara_shoot(capybara_target)
	_fengliu_register_whale_normal_attack()
	_fengliu_check_whale_triggers()


func _fengliu_prepare_whale_shot_context(capybara_target: Enemy) -> void:
	var capybara_muzzle_ref = get("capybara_muzzle")
	var origin: Vector2 = global_position
	if capybara_muzzle_ref != null and is_instance_valid(capybara_muzzle_ref):
		origin = capybara_muzzle_ref.global_position

	var target_rotation: float = 0.0
	if capybara_target != null and is_instance_valid(capybara_target):
		target_rotation = (capybara_target.global_position - origin).angle()

	_fengliu_whale_shot_origin = origin
	_fengliu_whale_shot_rotation = target_rotation

	for entry in _fengliu_whale_schedulers:
		var host = entry["host"]
		if host != null and is_instance_valid(host):
			host.set_shot_context(_current_weapon_stats, origin, target_rotation)


func _fengliu_play_whale_fire_feedback() -> void:
	if _current_weapon_stats == null:
		return

	var animation_player_ref = get("_animation_player")
	if animation_player_ref == null or not is_instance_valid(animation_player_ref):
		return
	if not animation_player_ref.has_animation("fire"):
		return

	var cooldown_seconds: float = max(float(_current_weapon_stats.cooldown) / 60.0, 0.01)
	animation_player_ref.play("fire", 0.0, 2.0 / cooldown_seconds)


func _fengliu_get_takeover_pairs() -> Array:
	var result: Array = []
	for entry in _fengliu_whale_schedulers:
		var scheduler = entry["scheduler"]
		if scheduler == null or not is_instance_valid(scheduler):
			continue
		for action in scheduler.get_takeover_actions():
			result.push_back({
				"entry": entry,
				"action": action,
			})
	return result


func _fengliu_register_whale_normal_attack() -> void:
	for entry in _fengliu_whale_schedulers:
		var scheduler = entry["scheduler"]
		if scheduler == null or not is_instance_valid(scheduler):
			continue
		if scheduler.should_count_attack():
			scheduler.register_normal_attack()


func _fengliu_check_whale_triggers() -> void:
	for entry in _fengliu_whale_schedulers:
		var scheduler = entry["scheduler"]
		if scheduler == null or not is_instance_valid(scheduler):
			continue
		scheduler.check_triggers()


# 投射物生成：把 shot 事件转给快照内的动作，并连接 hit 转发
func _capybara_connect_projectile_to_weapons(capybara_projectile: PlayerProjectile, capybara_weapons: Array) -> void:
	._capybara_connect_projectile_to_weapons(capybara_projectile, capybara_weapons)
	if capybara_projectile == null or not is_instance_valid(capybara_projectile):
		return

	_fengliu_attach_whale_actions_to_projectile(capybara_projectile, _fengliu_get_all_active_actions())


# 动作自行生成的炮弹：只携带该源武器 scheduler 的激活动作
func _fengliu_attach_whale_action_projectile(projectile, scheduler) -> void:
	var actions: Array = []
	if scheduler != null and is_instance_valid(scheduler):
		actions = scheduler.get_active_actions()
	_fengliu_attach_whale_actions_to_projectile(projectile, actions)


func _fengliu_attach_whale_actions_to_projectile(projectile, actions: Array) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return

	var actions_snapshot = actions.duplicate()
	projectile.set_meta(FENGLIU_WHALE_ACTIONS_META, actions_snapshot)
	if actions_snapshot.empty():
		return

	for action in actions_snapshot:
		if action != null and is_instance_valid(action):
			action.fengliu_on_projectile_shot(projectile)

	if projectile.has_signal("hit_something") and not projectile.is_connected("hit_something", self, "_fengliu_on_whale_action_projectile_hit"):
		var _error = projectile.connect("hit_something", self, "_fengliu_on_whale_action_projectile_hit", [projectile])


func _fengliu_get_all_active_actions() -> Array:
	var result: Array = []
	for entry in _fengliu_whale_schedulers:
		var scheduler = entry["scheduler"]
		if scheduler == null or not is_instance_valid(scheduler):
			continue
		result.append_array(scheduler.get_active_actions())
	return result


# 命中：按投射物快照转发，避免飞行途中武器变化影响已发射的子弹
func _fengliu_on_whale_action_projectile_hit(thing_hit, damage_dealt, projectile) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if not projectile.has_meta(FENGLIU_WHALE_ACTIONS_META):
		return

	var actions = projectile.get_meta(FENGLIU_WHALE_ACTIONS_META)
	if not actions is Array:
		return

	for action in actions:
		if action != null and is_instance_valid(action):
			action.fengliu_on_projectile_hit(thing_hit, damage_dealt, projectile)



# 每把武器实例各一份 scheduler：不做 weapon_id 去重。
# 同一把武器的动作共享普通攻击计数，不同武器之间互不影响。
func _fengliu_sync_whale_actions(capybara_weapons: Array) -> void:
	var signature_parts = PoolStringArray()
	for weapon in capybara_weapons:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not ("tier" in weapon):
			continue
		var weapon_actions = _fengliu_get_weapon_actions(weapon)
		if weapon_actions.empty():
			continue

		var action_paths = PoolStringArray()
		for action_resource in weapon_actions:
			if action_resource != null and is_instance_valid(action_resource):
				action_paths.append(str(action_resource.resource_path))

		var effect_count = 0
		var effects = weapon.get("effects")
		if effects is Array:
			effect_count = effects.size()

		signature_parts.append("%d:%d:%d:%s" % [
			weapon.get_instance_id(),
			int(weapon.tier),
			effect_count,
			action_paths.join(",")
		])

	signature_parts.sort()
	var signature = signature_parts.join("|")
	if signature == _fengliu_action_signature:
		return

	_fengliu_action_signature = signature

	for entry in _fengliu_whale_schedulers:
		var old_scheduler = entry["scheduler"]
		if old_scheduler != null and is_instance_valid(old_scheduler):
			old_scheduler.reset()
	_fengliu_whale_schedulers.clear()

	for weapon in capybara_weapons:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not ("tier" in weapon):
			continue

		var weapon_actions = _fengliu_get_weapon_actions(weapon)
		if weapon_actions.empty():
			continue

		var host = FengliuWhaleActionHost.new()
		host.setup(weapon, player_index, self)

		var scheduler = ACTION_SCHEDULER.new()
		host.scheduler = scheduler
		scheduler.setup(host, weapon_actions)

		_fengliu_whale_schedulers.push_back({
			"weapon_id": weapon.get_instance_id(),
			"host": host,
			"scheduler": scheduler,
		})


# 武器节点通过场景导出的 actions 数组暴露动作；WeaponData 则走 fengliu_get_actions()
func _fengliu_get_weapon_actions(weapon) -> Array:
	if weapon == null or not is_instance_valid(weapon):
		return []
	if weapon.has_method("fengliu_get_actions"):
		var by_method = weapon.fengliu_get_actions()
		if by_method is Array:
			return by_method
		return []
	if "actions" in weapon:
		var by_property = weapon.get("actions")
		if by_property is Array:
			return by_property
	return []

