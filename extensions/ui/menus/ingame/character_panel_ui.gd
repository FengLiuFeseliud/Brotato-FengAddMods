extends "res://ui/menus/ingame/character_panel_ui.gd"


const WholeImageBackground = preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_line_space/background_whole_image.gd")


# 场景烘焙的预览格（pos → autotile 坐标）
var _fengliu_baked_cells: Dictionary = {}


func _ready():
	if _tilemap != null:
		_fengliu_baked_cells = WholeImageBackground.capture_baked_cells(_tilemap)

	._ready()


func _update_bg():
	._update_bg()

	if _tilemap == null:
		return

	var background = RunData.get_background()

	# 仅移除可能残留的整图节点（本区域在预览里不铺整图）
	WholeImageBackground.clear(_tilemap)

	if WholeImageBackground.is_enabled(background):
		_tilemap.clear()
	else:
		WholeImageBackground.restore_baked_cells(_tilemap, _fengliu_baked_cells)
