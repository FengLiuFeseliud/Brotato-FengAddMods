extends UIProgressBar


# 血条上的「盾条」：外观与血条完全一致、尺寸与血条完全相同，外扩在血条正上方。
# 血条本体（ui/hud/ui_progress_bar.gd）只在 health_updated 时刷新，且受击闪白会改写 tint_progress，
# 所以盾条用独立子节点承载，由外部推送数据（玩家侧见 extensions/main.gd 的 fengliu_update_player_status_bars）。
# 用法：bar.set_status_items([[ratio, Color], ...])，ratio 取 0.0~1.0；无数据时全部隐藏。
# 布局：尺寸 = 父血条 rect_size（HUD 320x48 / 头顶·Boss 条 64x16）；
#       位置 = 血条上方，间隔 4px（与血条到经验条的间隔一致 = VBoxContainer 默认 separation）；
#       多项时继续往上叠。

const STATUS_SPACING: = 4.0


var _fengliu_status_bars: = []
var _fengliu_status_labels: = []
var _fengliu_status_items: = []


func _ready() -> void :
	# 生命周期回调由引擎按继承链自动调用，不要再 ._ready()
	connect("resized", self, "_fengliu_layout_status_bars")
	_fengliu_layout_status_bars()


# 外部推送状态项；数据无实质变化时不重排
func set_status_items(items: Array) -> void :
	if _fengliu_is_same_status_items(items):
		return

	_fengliu_status_items = items.duplicate(true)
	_fengliu_layout_status_bars()


func has_status_items() -> bool:
	return _fengliu_status_items.size() > 0


# 摆放同款盾条：每个状态项一条，与血条同尺寸，叠在血条上方并往上排
func _fengliu_layout_status_bars() -> void :
	var total: int = _fengliu_status_items.size()

	# 需要的条数不足时按需创建（每个都是与血条同款的 TextureProgress；同时按需建数值标签）
	while _fengliu_status_bars.size() < total:
		_fengliu_status_bars.push_back(_fengliu_create_status_bar())
		_fengliu_status_labels.push_back(_fengliu_create_value_label(_fengliu_status_bars.back()))

	for i in _fengliu_status_bars.size():
		var bar: TextureProgress = _fengliu_status_bars[i]

		if i >= total:
			bar.hide()
			continue

		var item = _fengliu_status_items[i]
		bar.rect_size = rect_size
		bar.rect_position = Vector2(0.0, -(rect_size.y + STATUS_SPACING) * float(i + 1))
		bar.tint_progress = item[1]
		bar.value = clamp(float(item[0]), 0.0, 1.0) * 100.0
		# 数值文本（与血条同款标签；无模板时保持为空）
		var label = _fengliu_status_labels[i]
		if label != null:
			label.text = _fengliu_get_item_text(item)
		bar.show()


# 与血条同款：贴图 / 边框厚度 / 填充模式全部从父节点复制
func _fengliu_create_status_bar() -> TextureProgress:
	var bar: = TextureProgress.new()
	bar.name = "FengliuStatusBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.texture_under = texture_under
	bar.texture_progress = texture_progress
	bar.texture_over = texture_over
	bar.nine_patch_stretch = true
	bar.stretch_margin_left = stretch_margin_left
	bar.stretch_margin_top = stretch_margin_top
	bar.stretch_margin_right = stretch_margin_right
	bar.stretch_margin_bottom = stretch_margin_bottom
	bar.fill_mode = fill_mode
	bar.tint_progress = Color.white
	bar.visible = false
	add_child(bar)
	return bar


# 数值标签：整块复制父血条自己的 MarginContainer（内含 LifeLabel）⇒ 字体/对齐/边距与血条完全一致；
# 头顶血条与 Boss 条没有该容器 ⇒ 返回 null（与原版一致，不显示数字）
func _fengliu_create_value_label(status_bar: TextureProgress) -> Label:
	var template := _fengliu_find_container_child(self)
	if template == null:
		return null

	var container: Control = template.duplicate(true)
	container.name = "ValueContainer"
	status_bar.add_child(container)

	var label := _fengliu_find_label(container)
	if label != null:
		label.set_message_translation(false)
	return label


func _fengliu_find_container_child(node: Node) -> Control:
	for child in node.get_children():
		if child is MarginContainer:
			return child
	return null


func _fengliu_find_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child
		var nested := _fengliu_find_label(child)
		if nested != null:
			return nested
	return null


func _fengliu_is_same_status_items(items: Array) -> bool:
	if items.size() != _fengliu_status_items.size():
		return false

	for i in items.size():
		if abs(float(items[i][0]) - float(_fengliu_status_items[i][0])) > 0.005:
			return false
		if items[i][1] != _fengliu_status_items[i][1]:
			return false
		# 文本也要比较，否则盾值变化时数字不刷新
		if _fengliu_get_item_text(items[i]) != _fengliu_get_item_text(_fengliu_status_items[i]):
			return false

	return true


func _fengliu_get_item_text(item) -> String:
	return str(item[2]) if item.size() > 2 else ""