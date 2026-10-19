extends "res://ui/hud/ui_timeline.gd"

var _fengliu_timeline_extension_logged = false


# 只给已注册的区域事件补时间轴图标
func _set_timeline_custom(current_position_index: int, character: CharacterData, from_wave: int = 1, to_wave: int = 20) -> void:
	._set_timeline_custom(current_position_index, character, from_wave, to_wave)

	if not _fengliu_timeline_extension_logged:
		_fengliu_timeline_extension_logged = true
		ModLoaderLog.info("Zone event timeline extension active", "FengAddMods")

	_fengliu_add_zone_event_icons()


func _fengliu_add_zone_event_icons() -> void:
	var service = RunData.fengliu_get_zone_event_service()
	if service == null:
		return

	var added = []

	for slot in _timeline_slot_container.get_children():
		# 原版重建时间轴时旧 slot 会先 queue_free，跳过它们
		if slot.is_queued_for_deletion():
			continue

		var icons = service.get_icons_for_wave(slot.value)
		if icons.size() == 0:
			continue

		var added_this_slot = []
		for icon_data in icons:
			var icon = icon_data.get("icon")
			if icon == null:
				continue

			if slot._event_icon.texture == null:
				slot._event_icon.texture = icon
			elif slot._second_event_icon.texture == null:
				slot._second_event_icon.texture = icon
				slot._second_event_icon.material = null
				slot._second_event_icon.visible = true
			else:
				# 两个图标槽都满了
				# 如果本 slot 还没加过事件图标，用最高优先级的事件图标顶掉第二个
				# 已经加过事件图标则不再用更低优先级的事件覆盖。
				if added_this_slot.size() == 0:
					slot._second_event_icon.texture = icon
					slot._second_event_icon.material = null
					slot._second_event_icon.visible = true
					added_this_slot.push_back(String(icon_data.get("id", "")))
				break

			added_this_slot.push_back(String(icon_data.get("id", "")))

		if added_this_slot.size() == 0:
			continue

		# 和原版“有事件图标”的 slot 保持一致：隐藏背景点、显示波次数字
		slot._point_text.visible = false
		slot._point_text.rect_min_size = Vector2(45, 45)
		slot._label.text = str(slot.value)
		slot._label.modulate.a = 1.0

		added.push_back("%d:%s" % [slot.value, str(added_this_slot)])

	if added.size() > 0:
		ModLoaderLog.info("Zone event timeline icons: %s" % str(added), "FengAddMods")
