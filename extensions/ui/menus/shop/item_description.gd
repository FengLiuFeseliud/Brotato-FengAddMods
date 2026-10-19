extends "res://ui/menus/shop/item_description.gd"


const FENGLIU_ZONE_EVENT_LINE_PREFIX := "FengliuZoneEventText"


func set_item(item_data: ItemParentData, player_index: int, item_count: = 1) -> void:
	.set_item(item_data, player_index, item_count)

	if not (item_data is DifficultyData):
		return

	_fengliu_append_zone_event_texts(item_data)


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
