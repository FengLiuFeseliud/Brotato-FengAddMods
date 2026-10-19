extends Control


# 独立护盾 HUD

const REFRESH_INTERVAL: = 0.1
const STATUS_SPACING: = 4.0


var _entries: Dictionary = {}
var _refresh_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_player_status(player_index: int, items: Array, life_bar, overhead_life_bar = null, overhead_visible: bool = true) -> void:
	if player_index < 0:
		return

	if life_bar == null or not is_instance_valid(life_bar):
		_hide_player(player_index)
		return

	var entry = _entries.get(player_index)
	if entry != null and (
		entry["life_bar"] != life_bar
		or entry["overhead_life_bar"] != overhead_life_bar
	):
		_free_entry(player_index)
		entry = null

	if entry == null:
		entry = {
			"player_index": player_index,
			"life_bar": life_bar,
			"overhead_life_bar": overhead_life_bar,
			"items": [],
			"bars": [],
			"overhead_bars": [],
			"overhead_visible": overhead_visible,
		}
		_entries[player_index] = entry

	entry["overhead_life_bar"] = overhead_life_bar
	entry["overhead_visible"] = overhead_visible
	entry["items"] = items.duplicate(true)

	_ensure_bars(entry)
	_apply_items(entry)
	_update_entry(entry)


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < REFRESH_INTERVAL:
		return
	_refresh_timer = 0.0

	var player_count: int = RunData.get_player_count()
	for player_index in _entries:
		var entry = _entries[player_index]
		if player_index >= player_count:
			_hide_entry(entry)
		else:
			_update_entry(entry)


func _ensure_bars(entry) -> void:
	var bars: Array = entry["bars"]
	var items: Array = entry["items"]
	while bars.size() < items.size():
		bars.push_back(_create_bar(entry["life_bar"], true))
	entry["bars"] = bars

	var overhead_bars: Array = entry["overhead_bars"]
	var overhead_life_bar = entry["overhead_life_bar"]
	if overhead_life_bar != null and is_instance_valid(overhead_life_bar):
		while overhead_bars.size() < items.size():
			overhead_bars.push_back(_create_bar(overhead_life_bar, false))
	entry["overhead_bars"] = overhead_bars


func _create_bar(life_bar, with_label: bool = true) -> Dictionary:
	var bar: = TextureProgress.new()
	bar.name = "FengliuShieldBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.texture_under = life_bar.texture_under
	bar.texture_progress = life_bar.texture_progress
	bar.texture_over = life_bar.texture_over
	bar.nine_patch_stretch = life_bar.nine_patch_stretch
	bar.stretch_margin_left = life_bar.stretch_margin_left
	bar.stretch_margin_top = life_bar.stretch_margin_top
	bar.stretch_margin_right = life_bar.stretch_margin_right
	bar.stretch_margin_bottom = life_bar.stretch_margin_bottom
	bar.fill_mode = life_bar.fill_mode
	bar.step = life_bar.step
	bar.theme = life_bar.theme
	bar.tint_progress = Color.white
	bar.visible = false
	add_child(bar)
	bar.raise()

	var container = null
	var label = null
	if with_label:
		var template = _find_container_child(life_bar)
		if template != null:
			container = template.duplicate(true)
			container.name = "ValueContainer"
			container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.show()
			bar.add_child(container)
			label = _find_label(container)

		if label == null:
			label = Label.new()
			label.name = "ShieldValueLabel"
			label.anchor_right = 1.0
			label.anchor_bottom = 1.0
			label.align = Label.ALIGN_CENTER
			label.valign = Label.VALIGN_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.theme = life_bar.theme
			bar.add_child(label)

		label.set_message_translation(false)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.show()

	return {
		"bar": bar,
		"container": container,
		"label": label,
	}


func _apply_items(entry) -> void:
	_apply_items_to_bars(entry["bars"], entry["items"])
	_apply_items_to_bars(entry["overhead_bars"], entry["items"])


func _apply_items_to_bars(bars: Array, items: Array) -> void:
	for i in bars.size():
		var bar_data = bars[i]
		var bar: TextureProgress = bar_data["bar"]
		if not is_instance_valid(bar):
			continue

		if i >= items.size():
			bar.hide()
			continue

		var item = items[i]
		bar.tint_progress = item[1]
		bar.value = clamp(float(item[0]), 0.0, 1.0) * 100.0

		var container = bar_data["container"]
		if container != null and is_instance_valid(container):
			container.show()

		var label = bar_data["label"]
		if label != null and is_instance_valid(label):
			label.text = _get_item_text(item)
			label.show()

		bar.show()


func _update_entry(entry) -> void:
	var life_bar = entry["life_bar"]
	var overhead_life_bar = entry["overhead_life_bar"]
	var items: Array = entry["items"]

	var screen_visible: bool = (
		life_bar != null
		and is_instance_valid(life_bar)
		and life_bar.visible
		and items.size() > 0
	)
	_update_bar_set(entry["bars"], life_bar, items, screen_visible)

	var overhead_visible: bool = (
		entry["overhead_visible"]
		and overhead_life_bar != null
		and is_instance_valid(overhead_life_bar)
		and items.size() > 0
	)
	_update_bar_set(entry["overhead_bars"], overhead_life_bar, items, overhead_visible)


func _update_bar_set(bars: Array, reference_bar, items: Array, should_show: bool) -> void:
	if not should_show:
		for bar_data in bars:
			var hidden_bar = bar_data["bar"]
			if is_instance_valid(hidden_bar):
				hidden_bar.hide()
		return

	var bar_size: Vector2 = reference_bar.rect_size
	if bar_size.x <= 0.0 or bar_size.y <= 0.0:
		bar_size = reference_bar.rect_min_size
	if bar_size.x <= 0.0 or bar_size.y <= 0.0:
		for bar_data in bars:
			var hidden_bar = bar_data["bar"]
			if is_instance_valid(hidden_bar):
				hidden_bar.hide()
		return

	# 用 canvas 坐标，避免 WorldUI 与 UI/HUD 的 CanvasLayer 变换差异
	var reference_position: Vector2 = reference_bar.get_global_transform_with_canvas().origin

	for i in bars.size():
		var bar_data = bars[i]
		var bar: TextureProgress = bar_data["bar"]
		if not is_instance_valid(bar):
			continue

		if i >= items.size():
			bar.hide()
			continue

		bar.rect_size = bar_size
		bar.rect_global_position = reference_position + Vector2(
			0.0,
			-(bar_size.y + STATUS_SPACING) * float(i + 1)
		)
		bar.show()


func _hide_entry(entry) -> void:
	for bar_data in entry["bars"]:
		var bar = bar_data["bar"]
		if is_instance_valid(bar):
			bar.hide()

	for bar_data in entry["overhead_bars"]:
		var overhead_bar = bar_data["bar"]
		if is_instance_valid(overhead_bar):
			overhead_bar.hide()


func _hide_player(player_index: int) -> void:
	var entry = _entries.get(player_index)
	if entry != null:
		_hide_entry(entry)


func _free_entry(player_index: int) -> void:
	var entry = _entries.get(player_index)
	if entry == null:
		return

	for bar_data in entry["bars"]:
		var bar = bar_data["bar"]
		if is_instance_valid(bar):
			bar.queue_free()

	for bar_data in entry["overhead_bars"]:
		var overhead_bar = bar_data["bar"]
		if is_instance_valid(overhead_bar):
			overhead_bar.queue_free()

	_entries.erase(player_index)


func _get_item_text(item) -> String:
	return str(item[2]) if item.size() > 2 else ""


func _find_container_child(node: Node) -> Control:
	for child in node.get_children():
		if child is MarginContainer:
			return child
	return null


func _find_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child
		var nested := _find_label(child)
		if nested != null:
			return nested
	return null
