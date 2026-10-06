extends "res://ui/menus/ingame/character_panel_ui.gd"


const WholeImageBackground = preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_line_space/background_whole_image.gd")


# 覆盖: 「整张图」模式下角色预览不显示场地图（清掉烘焙格子、也不铺整图），只留面板底色与边框；
#   其它背景仍走原版（预览里显示原来的格子拼贴）
func _update_bg():
	._update_bg()

	var background = RunData.get_background()

	if not WholeImageBackground.is_enabled(background):
		WholeImageBackground.clear(_tilemap)
		return

	# 预览里要「没有图」：移除可能残留的整图节点，并把场景烘焙的格子清掉
	WholeImageBackground.clear(_tilemap)
	_tilemap.clear()

