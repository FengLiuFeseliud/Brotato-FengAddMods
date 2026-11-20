extends "res://ui/menus/shop/item_description.gd"


const FENGLIU_RAINBOW = preload("res://mods-unpacked/FengLiu-FengAddMods/ui/fengliu_unique/fengliu_rainbow_visuals.gd")
const FENGLIU_ZONE_EVENT_LINE_PREFIX := "FengliuZoneEventText"
const FENGLIU_ACTION_LINE_PREFIX := "FengliuActionText"


# 独特武器：名称/图标同渐变（图标本身不加边框）
func set_item(item_data: ItemParentData, player_index: int, item_count: = 1) -> void:
	_fengliu_clear_rainbow()
	.set_item(item_data, player_index, item_count)

	if FENGLIU_RAINBOW.is_unique(item_data):
		FENGLIU_RAINBOW.apply_name(_name)
		FENGLIU_RAINBOW.apply_icon(_icon)

	# 区域事件说明（仅难度选择面板）
	if item_data is DifficultyData:
		_fengliu_append_zone_event_texts(item_data)

	_fengliu_prepend_action_effects(item_data, player_index)


# 自定义标题（非道具）时清掉上一次的彩虹
func set_custom_data(p_name: String, icon: Resource) -> void:
	_fengliu_clear_rainbow()
	.set_custom_data(p_name, icon)


# 清掉名称与图标的彩虹（同时清掉图标底框上可能残留的边框）
func _fengliu_clear_rainbow() -> void:
	FENGLIU_RAINBOW.clear_name(_name)
	FENGLIU_RAINBOW.clear_icon(_icon)
	FENGLIU_RAINBOW.clear_border(icon_panel)


# 难度描述追加当前区域/难度下可用的自定义事件说明
func _fengliu_append_zone_event_texts(item_data: DifficultyData) -> void:
	var effects = get_effects()
	if effects == null:
		return

	for child in effects.get_children():
		if String(child.name).begins_with(FENGLIU_ZONE_EVENT_LINE_PREFIX):
			effects.remove_child(child)
			child.queue_free()

	# 原版会为空的 tracking_text 创建一条尾部空 EffectLine；只移除这一条
	var children = effects.get_children()
	if children.size() > 0:
		var last_child = children[children.size() - 1]
		var text_descr = last_child.get("text_descr")
		if text_descr != null:
			var line_text = String(text_descr.text).strip_edges()
			var line_bbcode = String(text_descr.bbcode_text).strip_edges()
			if line_text == "" and line_bbcode == "":
				effects.remove_child(last_child)
				last_child.queue_free()

	var service = RunData.fengliu_get_zone_event_service()
	if service == null:
		return

	var zone = ZoneService.get_zone_data(RunData.current_zone)
	if zone == null:
		return

	var descriptions: Array = service.get_descriptions_for_difficulty(zone, int(item_data.value))
	if descriptions.size() == 0 or effect_line == null:
		return

	for i in descriptions.size():
		var description = descriptions[i]
		var line = effect_line.instance()
		line.name = FENGLIU_ZONE_EVENT_LINE_PREFIX + str(i)
		effects.add_child(line)
		line.call(
			"_display_special_text",
			String(description.get("text")),
			description.get("icon")
		)

	effects.visible = true


# 武器动作翻译：插到武器效果列表最前面
func _fengliu_prepend_action_effects(item_data, player_index: int) -> void:
	if not (item_data is WeaponData):
		return

	if hide_description_if_locked_in_codex and item_data._is_locked_in_codex():
		return

	if not item_data.has_method("_fengliu_get_action_effects_text"):
		return

	var effects = get_effects()
	if effects == null or effect_line == null:
		return

	for child in effects.get_children():
		if String(child.name).begins_with(FENGLIU_ACTION_LINE_PREFIX):
			effects.remove_child(child)
			child.queue_free()

	var action_text: String = item_data._fengliu_get_action_effects_text(player_index)
	if action_text == "":
		return

	var lines = action_text.split("\n")
	var prepend_index := 0
	for line_text in lines:
		if String(line_text).strip_edges() == "":
			continue

		var line = effect_line.instance()
		line.name = FENGLIU_ACTION_LINE_PREFIX + str(prepend_index)
		effects.add_child(line)
		line.call("_display_special_text", String(line_text), null)
		effects.move_child(line, prepend_index)
		prepend_index += 1

	effects.visible = true

