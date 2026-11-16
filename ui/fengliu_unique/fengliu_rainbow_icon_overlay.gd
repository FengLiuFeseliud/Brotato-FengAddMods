extends ColorRect


const ICON_SHADER = preload("res://mods-unpacked/FengLiu-FengAddMods/ui/fengliu_unique/fengliu_rainbow_icon.gdshader")

var _icon_material: ShaderMaterial


func _init() -> void:
	# 材质只建一次，叠加层复用时只更新参数
	_icon_material = ShaderMaterial.new()
	_icon_material.shader = ICON_SHADER


func _ready() -> void:
	# 图标叠加层只负责加色，不接收鼠标事件
	mouse_filter = MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 1)
	material = _icon_material

	connect("resized", self, "_update_size")
	if get_parent() is Control:
		get_parent().connect("resized", self, "_update_size")

	call_deferred("_update_size")


func set_icon_texture(icon: Texture) -> void:
	if icon == null:
		visible = false
		return

	# 用图标自身作为透明遮罩，只在武器实际像素上加色
	_icon_material.set_shader_param("icon_texture", icon)
	visible = true
	call_deferred("_update_size")


func _update_size() -> void:
	if not is_inside_tree():
		return

	# 叠加层尺寸变化后同步给 shader
	_icon_material.set_shader_param("overlay_size", rect_size)
