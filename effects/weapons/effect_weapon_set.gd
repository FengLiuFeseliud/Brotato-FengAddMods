extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：武器套装
#   按 [[武器, 需要数], ...] 统计玩家当前武器，全部达标时激活
#   active_effects，任意一条不达标或最后一个持有者被移除时撤销。
#   条件满足/失效时也可覆写 weapon_set_on_active / weapon_set_on_inactive。
#   运行时 custom_key：无（状态存在效果字典的 weapon_set_states 槽）
#   支持来源：武器 / 道具 / 角色 / 套装效果；升级项不保留效果实例，不参与判定。
# ------------------------------------------------------------
# 效果值：
#   weapon_requirements  每项 [武器, 需要数]；武器可为 WeaponData 或武器 id 字符串
#                        （效果与需求武器互相引用时用字符串，避免 .tres 资源循环；
#                          字符串在家族模式填 weapon_id，精确模式填 my_id）
#   match_exact_tier     false=按 weapon_id 统计同家族；true=按 my_id 精确品阶
#   set_key              同一套配置的唯一标识（留空时按资源路径/需求自动派生）
#   active_effects       条件满足时要应用的效果列表
# ============================================================

# 与 extensions/singletons/run_data.gd 共用（通过 preload 读取该常量）
const STATE_SLOT_KEY := "weapon_set_states"
const REQUIREMENT_MODE_RESOURCE := 0
const REQUIREMENT_MODE_ID := 1

export (Array) var weapon_requirements = []
export (bool) var match_exact_tier = false
export (String) var set_key = ""
export (Array, Resource) var active_effects = []


static func get_id() -> String:
	return "fengliu_weapon_set"


# 条件型效果不适合异变复制，避免复制出重复的整套配置
func fengliu_can_be_copied_by_mutation() -> bool:
	return false


func fengliu_get_effect_init_value():
	return []


func apply(player_index: int) -> void:
	_request_refresh(player_index)


func unapply(player_index: int) -> void:
	_request_refresh(player_index)


# 由 RunData 全局刷新统一调用；也可由子类/外部主动调用
func weapon_set_refresh(player_index: int) -> void:
	if player_index < 0 or player_index >= RunData.players_data.size() or player_index == RunData.DUMMY_PLAYER_INDEX:
		return

	var effects = RunData.get_player_effects(player_index)
	var state = effects.get(_state_slot_hash(), {})
	# 老存档 / 首次使用：补一个空状态字典
	if not (state is Dictionary):
		state = {}
		effects[_state_slot_hash()] = state

	var key_hash: int = Keys.generate_hash(get_set_key())
	var was_active: bool = int(state.get(key_hash, 0)) != 0
	var should_active: bool = weapon_set_has_holder(player_index) and weapon_set_requirements_met(player_index)
	if should_active == was_active:
		return

	# 先落状态再执行副作用，避免钩子里再次触发重算时重复应用
	state[key_hash] = 1 if should_active else 0
	# get() 的默认值可能是临时字典：改完必须写回，保证状态真正落到玩家效果字典
	effects[_state_slot_hash()] = state
	if should_active:
		weapon_set_on_active(player_index)
	else:
		weapon_set_on_inactive(player_index)


# 默认激活：应用 active_effects；子类可覆写做自定义逻辑
func weapon_set_on_active(player_index: int) -> void:
	if active_effects.size() == 0:
		return
	RunData.apply_effects_array(active_effects, player_index)


# 默认撤销：移除 active_effects；子类可覆写做自定义逻辑
func weapon_set_on_inactive(player_index: int) -> void:
	if active_effects.size() == 0:
		return
	RunData.unapply_effects_array(active_effects, player_index)


# 当前玩家是否还持有本效果（武器 / 道具 / 角色 / 套装效果来源）
func weapon_set_has_holder(player_index: int) -> bool:
	var key: String = get_set_key()
	for holder_effect in _collect_holder_effects(player_index):
		if holder_effect == null or not holder_effect.has_method("get_set_key"):
			continue
		if holder_effect.get_id() == get_id() and holder_effect.get_set_key() == key:
			return true
	return false


# 全部武器需求是否达标；没有有效需求时视为不达标，避免空配置永久生效
func weapon_set_requirements_met(player_index: int) -> bool:
	var requirements := _get_valid_requirements()
	if requirements.size() == 0:
		return false

	var checked_count := 0
	for requirement in requirements:
		var required_id: String = _get_requirement_match_id(requirement[0])
		if required_id == "":
			continue

		checked_count += 1
		var required_count: int = int(requirement[1])
		if _count_matching_weapons(player_index, required_id) < required_count:
			return false

	# 全部条目都无法解析时视为不达标，避免坏配置永久生效
	return checked_count > 0


# 模板描述：{0}=需求、{1}=数值、{2}=属性
func get_args(player_index: int) -> Array:
	var show_counts: bool = _can_check_trigger(player_index) and not weapon_set_requirements_met(player_index)
	return [
		_build_requirements_text(true, true, show_counts, player_index),
		_build_bonus_text(),
		_build_attribute_text(true)
	]


func get_args_tool() -> Array:
	return [
		_build_requirements_text(false, false, false, -1),
		_build_bonus_text(),
		_build_attribute_text(false)
	]


# 自定义描述：已触发时数值绿色；未触发时数值/属性/后缀整段灰色
func get_text(player_index: int, colored: bool = true) -> String:
	var key_text: String = text_key.to_upper() if text_key.length() > 0 else key.to_upper()
	var can_check: bool = _can_check_trigger(player_index)
	var triggered := true
	if can_check:
		triggered = weapon_set_requirements_met(player_index)

	var is_untriggered: bool = can_check and not triggered
	var display_key: String = key_text
	# 彩色模式下用专用 key，把 {1}{2}（未触发）整体包进灰色
	if colored and is_untriggered:
		display_key = key_text + "_UNTRIGGERED"

	var args := [
		_build_requirements_text(true, colored, is_untriggered, player_index),
		_build_bonus_text(),
		_build_attribute_text(true)
	]

	var signs := []
	if colored and args.size() > 1:
		# 用参数自身的正负号着色（基类 get_sign 取的是效果自身 value，本效果 value 恒为 0）
		var bonus_value := int(args[1])
		var value_sign: int = Sign.NEUTRAL
		if not is_untriggered:
			if bonus_value > 0:
				value_sign = Sign.POSITIVE
			elif bonus_value < 0:
				value_sign = Sign.NEGATIVE

		signs = [
			Sign.NEUTRAL,
			value_sign,
			value_sign
		]

	var text: String = Text.text(display_key, args, signs)
	# 非彩色模式没有灰色标签，单独补纯文本后缀
	if not colored and is_untriggered:
		text += tr("EFFECT_WEAPON_SET_NOT_TRIGGERED")
	return text


# 描述图标沿用第一个子效果的图标（例如最大生命）
func get_icon(player_index: int) -> Texture:
	for effect in active_effects:
		if effect != null:
			return effect.get_icon(player_index)
	return .get_icon(player_index)


# 同一套配置的唯一标识：优先 set_key，其次资源路径，最后按需求签名派生
func get_set_key() -> String:
	if set_key != "":
		return set_key
	if resource_path != "":
		return resource_path

	var parts := []
	for requirement in _get_valid_requirements():
		parts.push_back("%s:%d" % [_get_requirement_match_id(requirement[0]), int(requirement[1])])
	return "weapon_set|%s|%s" % [str(match_exact_tier), PoolStringArray(parts).join("|")]


func serialize() -> Dictionary:
	var serialized = .serialize()
	# 把派生出来的 set_key 也写进存档，避免读档后资源路径丢失导致状态键变化
	serialized["set_key"] = get_set_key()
	serialized["weapon_requirements"] = _serialize_requirements()
	serialized["active_effects"] = _serialize_active_effects()
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	if serialized.has("set_key"):
		set_key = str(serialized["set_key"])
	if serialized.has("weapon_requirements"):
		weapon_requirements = _deserialize_requirements(serialized["weapon_requirements"])
	if serialized.has("active_effects"):
		active_effects = _deserialize_active_effects(serialized["active_effects"])


func _request_refresh(player_index: int) -> void:
	if RunData.has_method("refresh_weapon_set_effects"):
		RunData.refresh_weapon_set_effects(player_index)
	else:
		weapon_set_refresh(player_index)


func _state_slot_hash() -> int:
	return Keys.generate_hash(STATE_SLOT_KEY)


# 收集当前可能携带本效果的实例：武器、道具（含角色）、当前角色、已生效套装效果
func _collect_holder_effects(player_index: int) -> Array:
	var result := []
	var player_data = RunData.players_data[player_index]
	_append_holder_effects(result, player_data.weapons)
	_append_holder_effects(result, player_data.items)
	_append_holder_effects(result, [player_data.current_character])

	for entry in player_data.active_set_effects:
		if entry is Array and entry.size() > 1 and entry[1] != null:
			result.push_back(entry[1])

	return result


func _append_holder_effects(result: Array, holders: Array) -> void:
	for holder in holders:
		if holder == null or holder.effects == null:
			continue
		result.append_array(holder.effects)


func _get_valid_requirements() -> Array:
	var result := []
	for requirement in weapon_requirements:
		if not (requirement is Array) or requirement.size() < 2:
			continue

		var weapon = requirement[0]
		var count: int = int(requirement[1])
		if count <= 0:
			continue

		if weapon is WeaponData:
			result.push_back([weapon, count])
		elif weapon is String and str(weapon) != "":
			result.push_back([str(weapon), count])

	return result


# 需求条目的匹配 id：资源按 weapon_id / my_id；字符串按 weapon_id / my_id
func _get_requirement_match_id(weapon) -> String:
	if weapon is WeaponData:
		return weapon.my_id if match_exact_tier else weapon.weapon_id
	if weapon is String:
		return str(weapon)
	return ""


func _count_matching_weapons(player_index: int, required_id: String) -> int:
	var count := 0
	for weapon in RunData.get_player_weapons_ref(player_index):
		if weapon == null:
			continue
		var owned_id: String = weapon.my_id if match_exact_tier else weapon.weapon_id
		if owned_id == required_id:
			count += 1
	return count


func _can_check_trigger(player_index: int) -> bool:
	return player_index >= 0 and player_index < RunData.players_data.size()


func _build_requirements_text(translated: bool, colored: bool = true, show_counts: bool = false, player_index: int = -1) -> String:
	var parts := []
	var format_text: String = tr("EFFECT_WEAPON_SET_REQUIREMENT_FORMAT") if translated else "{0} {1}"
	var separator: String = tr("EFFECT_WEAPON_SET_REQUIREMENT_SEPARATOR") if translated else ", "
	for requirement in _get_valid_requirements():
		var required_id: String = _get_requirement_match_id(requirement[0])
		if required_id == "":
			continue

		var required_count: int = int(requirement[1])
		var count_text := str(required_count)
		# 未触发时显示「当前/需要」，已触发时只显示需要数
		if show_counts and _can_check_trigger(player_index):
			var owned_count: int = _count_matching_weapons(player_index, required_id)
			count_text = "%d/%d" % [owned_count, required_count]

		# 只给数量上色，武器名保持普通颜色
		if colored:
			count_text = "[color=lime]%s[/color]" % count_text
		var name_text: String = _get_requirement_name(requirement[0], translated)
		parts.push_back(format_text.replace("{0}", count_text).replace("{1}", name_text))

	return PoolStringArray(parts).join(separator)


# 只有一个子效果时把数值暴露给翻译占位符 {1}（例如最大生命 +100 的 100）
func _build_bonus_text() -> String:
	if active_effects.size() != 1 or active_effects[0] == null:
		return ""
	return str(active_effects[0].value)


# 属性名来自子效果：优先 stat_displayed_name，否则用 key 的翻译
func _build_attribute_text(translated: bool) -> String:
	if active_effects.size() != 1 or active_effects[0] == null:
		return ""

	var attribute_key: String = active_effects[0].key
	if "stat_displayed_name" in active_effects[0] and str(active_effects[0].stat_displayed_name) != "":
		attribute_key = str(active_effects[0].stat_displayed_name)
	if attribute_key == "":
		return ""

	return tr(attribute_key.to_upper()) if translated else attribute_key.to_upper()


func _get_requirement_name(weapon, translated: bool) -> String:
	var weapon_data = null
	if weapon is WeaponData:
		weapon_data = weapon
	elif weapon is String:
		weapon_data = _find_weapon_for_requirement(str(weapon))

	if weapon_data == null:
		return str(weapon)

	var display_name: String = weapon_data.name if weapon_data.name != "" else weapon_data.weapon_id
	if translated:
		return tr(display_name)
	return display_name


# 字符串需求按当前匹配口径查武器：家族模式查 weapon_id，精确模式查 my_id
func _find_weapon_for_requirement(weapon_id: String):
	if not is_instance_valid(ItemService):
		return null
	for weapon in ItemService.get_weapons():
		if weapon == null:
			continue
		if match_exact_tier:
			if weapon.my_id == weapon_id:
				return weapon
		elif weapon.weapon_id == weapon_id:
			return weapon
	return null


func _find_weapon_by_id(weapon_id: String):
	if weapon_id == "" or not is_instance_valid(ItemService):
		return null
	for weapon in ItemService.get_weapons():
		if weapon != null and weapon.weapon_id == weapon_id:
			return weapon
	return null


func _find_weapon_by_my_id(my_id: String):
	if my_id == "" or not is_instance_valid(ItemService):
		return null
	for weapon in ItemService.get_weapons():
		if weapon != null and weapon.my_id == my_id:
			return weapon
	return null


func _serialize_requirements() -> Array:
	var result := []
	for requirement in _get_valid_requirements():
		var weapon = requirement[0]
		var count: int = int(requirement[1])
		var mode: int = REQUIREMENT_MODE_ID
		var path := ""
		var weapon_id := ""
		var my_id := ""

		if weapon is WeaponData:
			mode = REQUIREMENT_MODE_RESOURCE
			path = weapon.resource_path
			weapon_id = weapon.weapon_id
			my_id = weapon.my_id
		else:
			weapon_id = str(weapon)

		result.push_back([mode, path, weapon_id, my_id, count])

	return result


func _deserialize_requirements(serialized_value) -> Array:
	var result := []
	if not (serialized_value is Array):
		return result

	for entry in serialized_value:
		if not (entry is Array) or entry.size() < 5:
			continue

		var mode: int = int(entry[0])
		var path := str(entry[1])
		var weapon_id := str(entry[2])
		var my_id := str(entry[3])
		var count: int = int(entry[4])
		if count <= 0:
			continue

		# 字符串需求直接还原，保持家族 / 精确口径不变
		if mode == REQUIREMENT_MODE_ID:
			if weapon_id != "":
				result.push_back([weapon_id, count])
			continue

		var weapon = null
		if path != "" and ResourceLoader.exists(path):
			var loaded = load(path)
			if loaded is WeaponData:
				weapon = loaded

		if weapon == null:
			weapon = _find_weapon_by_id(weapon_id)
		if weapon == null:
			weapon = _find_weapon_by_my_id(my_id)

		# 资源找不到时退回字符串，保证条件仍可判定
		if weapon == null:
			if match_exact_tier and my_id != "":
				result.push_back([my_id, count])
			elif weapon_id != "":
				result.push_back([weapon_id, count])
			elif my_id != "":
				result.push_back([my_id, count])
			continue

		result.push_back([weapon, count])

	return result


func _serialize_active_effects() -> Array:
	var result := []
	for effect in active_effects:
		if effect == null:
			continue

		var script_path := ""
		var effect_script = effect.get_script()
		if effect_script != null:
			script_path = effect_script.resource_path

		result.push_back({
			"script_path": script_path,
			"effect": effect.serialize()
		})

	return result


func _deserialize_active_effects(serialized_value) -> Array:
	var result := []
	if not (serialized_value is Array):
		return result

	for entry in serialized_value:
		if not (entry is Dictionary):
			continue

		var serialized_effect = entry.get("effect", null)
		# 兼容直接存 Effect.serialize() 的格式
		if not (serialized_effect is Dictionary):
			if entry.has("effect_id"):
				serialized_effect = entry
			else:
				continue

		var effect = _deserialize_effect(str(entry.get("script_path", "")), serialized_effect)
		if effect != null:
			result.push_back(effect)

	return result


func _deserialize_effect(script_path: String, serialized_effect: Dictionary):
	# 优先按脚本路径还原，支持原版 / mod 的各种效果脚本
	if script_path != "" and ResourceLoader.exists(script_path):
		var effect_script = load(script_path)
		if effect_script != null and effect_script is GDScript:
			var instance = effect_script.new()
			if instance is Effect:
				instance.deserialize_and_merge(serialized_effect)
				return instance

	if is_instance_valid(ItemService):
		for registered_effect in ItemService.effects:
			if registered_effect == null:
				continue
			if registered_effect.get_id() == str(serialized_effect.get("effect_id", "")):
				var instance = registered_effect.new()
				instance.deserialize_and_merge(serialized_effect)
				return instance

	var fallback = Effect.new()
	fallback.deserialize_and_merge(serialized_effect)
	return fallback

