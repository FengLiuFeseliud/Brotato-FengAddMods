extends "res://items/global/inventory_element.gd"


const FENGLIU_RAINBOW = preload("res://mods-unpacked/FengLiu-FengAddMods/ui/fengliu_unique/fengliu_rainbow_visuals.gd")


# 独特武器：库存格右上→左下彩虹边框。
func set_element(item_data: Resource) -> void:
	.set_element(item_data)

	if item_data != null and FENGLIU_RAINBOW.is_unique(item_data):
		FENGLIU_RAINBOW.apply_border(self, 0.0, 8.0)
	else:
		FENGLIU_RAINBOW.clear_border(self)
