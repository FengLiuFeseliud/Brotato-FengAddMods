extends "res://mods-unpacked/Dbear-Capybara/contents/pets/blue_whale/blue_whale.gd"


# ============================================================
# Capybara 蓝鲸兼容层（FengAddMods）
# 路径约定：extensions/mods/<mod名>/<原mod路径>
#
# 保留蓝鲸对本 mod 构筑物的环绕/拖动，并在移动前做存活/初始化/脚本检查；
# 重写 refresh/collect 的遍历，避免基类直接访问已失效对象。
# ============================================================

const FENGLIU_WHALE_ACTIONS_META := "fengliu_whale_action_snapshot"


# 动作宿主：只缓存源武器的 effects/tier/player_index，避免武器释放后访问失效 Node。
class FengliuWhaleActionHost:
	extends Reference

	var effects: Array = []
	var player_index: int = -1
	var tier: int = 0

	func setup(source_weapon, source_player_index: int) -> void:
		player_index = source_player_index
		if source_weapon == null or not is_instance_valid(source_weapon):
			return
		var source_effects = source_weapon.get("effects")
		if source_effects is Array:
			effects = source_effects.duplicate()
		tier = int(source_weapon.tier)

	func fengliu_get_action_tier() -> int:
		return tier

	func fengliu_uses_custom_projectile_forms() -> bool:
		return false


var _fengliu_whale_actions: Array = []
var _fengliu_action_signature: String = ""


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
	._capybara_shoot(capybara_target)


# 投射物生成：把 shot 事件转给快照内的动作，并连接 hit 转发
func _capybara_connect_projectile_to_weapons(capybara_projectile: PlayerProjectile, capybara_weapons: Array) -> void:
	._capybara_connect_projectile_to_weapons(capybara_projectile, capybara_weapons)
	if capybara_projectile == null or not is_instance_valid(capybara_projectile):
		return

	var actions_snapshot = _fengliu_whale_actions.duplicate()
	capybara_projectile.set_meta(FENGLIU_WHALE_ACTIONS_META, actions_snapshot)
	if actions_snapshot.empty():
		return

	for action in actions_snapshot:
		if action != null and is_instance_valid(action):
			action.fengliu_on_projectile_shot(capybara_projectile)

	if capybara_projectile.has_signal("hit_something") and not capybara_projectile.is_connected("hit_something", self, "_fengliu_on_whale_action_projectile_hit"):
		var _error = capybara_projectile.connect("hit_something", self, "_fengliu_on_whale_action_projectile_hit", [capybara_projectile])


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



# 每把武器实例各一份动作：不做 weapon_id 去重。
# 只桥接 ranged 动作；只启动 trigger_count <= 0 的常驻动作（与 builder_turret 一致）。
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
	_fengliu_whale_actions.clear()

	for weapon in capybara_weapons:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not ("tier" in weapon):
			continue
		var weapon_actions = _fengliu_get_weapon_actions(weapon)
		if weapon_actions.empty():
			continue

		var host = FengliuWhaleActionHost.new()
		host.setup(weapon, player_index)

		for action_resource in weapon_actions:
			if action_resource == null or not is_instance_valid(action_resource):
				continue
			if not action_resource.has_method("fengliu_is_ranged_action"):
				continue

			var action = action_resource.duplicate()
			if action == null:
				continue

			action.fengliu_setup(host)

			# 触发型动作需要攻击计数调度，蓝鲸侧暂不启用
			if action.fengliu_get_trigger_count() > 0:
				continue

			action.fengliu_start()
			_fengliu_whale_actions.append(action)


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

