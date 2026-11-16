extends Reference


const BORDER_OVERLAY = preload("res://mods-unpacked/FengLiu-FengAddMods/ui/fengliu_unique/fengliu_rainbow_border_overlay.gd")
const ICON_OVERLAY = preload("res://mods-unpacked/FengLiu-FengAddMods/ui/fengliu_unique/fengliu_rainbow_icon_overlay.gd")
const RAINBOW_TEXT_SHADER = preload("res://mods-unpacked/FengLiu-FengAddMods/ui/fengliu_unique/fengliu_rainbow_text.gdshader")
const UNIQUE_SET_ID = "set_fengliu_unique"
const BORDER_NAME = "FengliuRainbowBorder"
const FILL_NAME = "FengliuRainbowBorderFill"
const ICON_NAME = "FengliuRainbowIcon"
const NAME_MATERIAL_META = "fengliu_rainbow_material"
const NAME_ORIGINAL_MATERIAL_META = "fengliu_rainbow_original_material"


# 武器是否带「独特」套装
static func is_unique(item) -> bool:
	if not (item is WeaponData):
		return false
	if item.sets == null:
		return false

	# 套装 id 以字符串比对，避免哈希尚未生成时的时序问题
	for item_set in item.sets:
		if item_set != null and item_set.my_id == UNIQUE_SET_ID:
			return true

	return false


# 名称：换上彩虹文字材质（保留原材质以便还原）
static func apply_name(label: Label) -> void:
	if label == null:
		return

	if not label.has_meta(NAME_ORIGINAL_MATERIAL_META):
		label.set_meta(NAME_ORIGINAL_MATERIAL_META, label.material)

	var text_material = label.get_meta(NAME_MATERIAL_META) if label.has_meta(NAME_MATERIAL_META) else null
	if text_material == null:
		text_material = ShaderMaterial.new()
		text_material.shader = RAINBOW_TEXT_SHADER
		label.set_meta(NAME_MATERIAL_META, text_material)

	label.material = text_material


# 名称：还原原始材质
static func clear_name(label: Label) -> void:
	if label == null:
		return

	if label.has_meta(NAME_ORIGINAL_MATERIAL_META):
		label.material = label.get_meta(NAME_ORIGINAL_MATERIAL_META)
	else:
		label.material = null


# 图标：叠加与边框同渐变的加色层（保留原图）
static func apply_icon(icon: Control) -> void:
	if icon == null:
		return

	var overlay = icon.get_node_or_null(ICON_NAME)
	if overlay == null:
		overlay = ICON_OVERLAY.new()
		overlay.name = ICON_NAME
		icon.add_child(overlay)
		overlay.set_anchors_and_margins_preset(Control.PRESET_WIDE)

	# 传入图标纹理给 shader 做透明遮罩
	if icon is TextureRect:
		overlay.set_icon_texture(icon.texture)
	else:
		overlay.set_icon_texture(null)

	icon.move_child(overlay, icon.get_child_count() - 1)


# 图标：移除彩虹加色层
static func clear_icon(icon: Control) -> void:
	if icon == null:
		return

	_remove_node(icon.get_node_or_null(ICON_NAME))


# 面板：右上→左下彩虹边框，可选内部淡填充
static func apply_border(panel: Control, fill_alpha: float = 0.0, corner_radius: float = 8.0) -> void:
	if panel == null:
		return

	# 边框层放在最后，确保边缘不被图标/内容遮挡
	var border = panel.get_node_or_null(BORDER_NAME)
	if border == null:
		border = BORDER_OVERLAY.new()
		border.name = BORDER_NAME
		panel.add_child(border)
		border.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	border.configure(0.0, corner_radius, 3.0)
	panel.move_child(border, panel.get_child_count() - 1)

	# 淡填充层放在索引 0，背景之上、内容之下
	var fill = panel.get_node_or_null(FILL_NAME)
	if fill_alpha > 0.0:
		if fill == null:
			fill = BORDER_OVERLAY.new()
			fill.name = FILL_NAME
			panel.add_child(fill)
			fill.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		fill.configure(fill_alpha, corner_radius, 0.0)
		panel.move_child(fill, 0)
	elif fill != null:
		_remove_node(fill)


# 面板：移除边框与淡填充
static func clear_border(panel: Control) -> void:
	if panel == null:
		return

	_remove_node(panel.get_node_or_null(BORDER_NAME))
	_remove_node(panel.get_node_or_null(FILL_NAME))


# 先移出场景树再释放，避免同帧复用待释放节点
static func _remove_node(node: Node) -> void:
	if node == null:
		return

	var parent = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()
