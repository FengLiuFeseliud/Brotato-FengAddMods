extends "res://ui/menus/shop/item_description.gd"


const FENGLIU_RAINBOW = preload("res://mods-unpacked/FengLiu-FengAddMods/ui/fengliu_unique/fengliu_rainbow_visuals.gd")


# 独特武器：名称/图标同渐变（图标本身不加边框）
func set_item(item_data: ItemParentData, player_index: int, item_count: = 1) -> void:
	_fengliu_clear_rainbow()
	.set_item(item_data, player_index, item_count)

	if not FENGLIU_RAINBOW.is_unique(item_data):
		return

	FENGLIU_RAINBOW.apply_name(_name)
	FENGLIU_RAINBOW.apply_icon(_icon)


# 自定义标题（非道具）时清掉上一次的彩虹
func set_custom_data(p_name: String, icon: Resource) -> void:
	_fengliu_clear_rainbow()
	.set_custom_data(p_name, icon)


# 清掉名称与图标的彩虹（同时清掉图标底框上可能残留的边框）
func _fengliu_clear_rainbow() -> void:
	FENGLIU_RAINBOW.clear_name(_name)
	FENGLIU_RAINBOW.clear_icon(_icon)
	FENGLIU_RAINBOW.clear_border(icon_panel)
