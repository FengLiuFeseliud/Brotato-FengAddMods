extends "res://ui/menus/ingame/item_panel_ui.gd"


const FENGLIU_RAINBOW = preload("res://mods-unpacked/FengLiu-FengAddMods/ui/fengliu_unique/fengliu_rainbow_visuals.gd")


# 独特武器：详情面板右上→左下彩虹边框 + 内部淡淡一层
func _update_stylebox() -> void:
	FENGLIU_RAINBOW.clear_border(self)
	._update_stylebox()

	if not FENGLIU_RAINBOW.is_unique(item_data):
		return

	FENGLIU_RAINBOW.apply_border(self, 0.06, 12.0)
