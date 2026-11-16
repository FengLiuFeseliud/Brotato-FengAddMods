extends ColorRect


const BORDER_SHADER = preload("res://mods-unpacked/FengLiu-FengAddMods/ui/fengliu_unique/fengliu_rainbow_border.gdshader")

var _border_material: ShaderMaterial


func _init() -> void:
	# 材质只建一次，叠加层复用时只更新参数
	_border_material = ShaderMaterial.new()
	_border_material.shader = BORDER_SHADER


func _ready() -> void:
	# 叠加层只负责绘制边框/淡填充，不接收鼠标事件
	mouse_filter = MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 1)
	material = _border_material

	connect("resized", self, "_update_size")
	if get_parent() is Control:
		get_parent().connect("resized", self, "_update_size")

	call_deferred("_update_size")


func configure(fill_alpha: float, corner_radius: float, border_width: float) -> void:
	_border_material.set_shader_param("fill_alpha", fill_alpha)
	_border_material.set_shader_param("corner_radius", corner_radius)
	_border_material.set_shader_param("border_width", border_width)
	call_deferred("_update_size")


func _update_size() -> void:
	if not is_inside_tree():
		return

	# 叠加层尺寸变化后同步给 shader
	_border_material.set_shader_param("overlay_size", rect_size)
