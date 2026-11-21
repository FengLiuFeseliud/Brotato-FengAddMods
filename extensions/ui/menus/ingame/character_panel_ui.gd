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


# 原版会把缺失的起始道具/武器（如未拥有 DLC 的内容）以 null 塞进 list_of_items，
func set_data(p_item_data: ItemParentData, _player_index: int) -> void :
	on_hide_inventory_popup()
	_random_icon_container.visible = false
	_global_container.visible = true
	_chara_visual.visible = true
	_rightPanel.visible = true

	if RunData.is_coop_run:
		_characterName.modulate = CoopService.player_colors[player_index]
		_left_panel_color.self_modulate = CoopService.player_colors[player_index]
		_left_panel_color.self_modulate.v = 0.5
		_left_panel_color.self_modulate.a = 0.35
		_inventory_container.self_modulate = Color(1, 1, 1, 0)
	else:
		_characterName.modulate = Color(1, 1, 1)
		_inventory_container.self_modulate = Color(1, 1, 1, 1)
		_left_panel_color.self_modulate.a = 0

	item_data = p_item_data
	_item_description.set_item(p_item_data, player_index)

	_characterName.text = item_data.name

	var list_of_items: Array = []
	for effect in item_data.effects:
		if effect == null:
			continue

		match effect.custom_key_hash:
			Keys.starting_weapon_hash:
				_fengliu_append_preview_item(list_of_items, ItemService.weapons, effect.key_hash)
			Keys.starting_item_hash:
				_fengliu_append_preview_item(list_of_items, ItemService.items, effect.key_hash)
			Keys.cursed_starting_item_hash:
				_fengliu_append_preview_item(list_of_items, ItemService.items, effect.key_hash)
			Keys.cursed_starting_weapon_hash:
				_fengliu_append_preview_item(list_of_items, ItemService.weapons, effect.key_hash)

	_scroll_box_inventory.rect_min_size.x = list_of_items.size() * _scroll_box_inventory.rect_min_size.y
	_inventory.set_elements(list_of_items, false, true)
	apply_objects_display(list_of_items, p_item_data)
	_update_stylebox()


# 缺失的起始道具/武器（DLC 未拥有、资源被删等）不进入预览列表
func _fengliu_append_preview_item(list_of_items: Array, pool: Array, item_hash: int) -> void:
	var item = ItemService.get_element(pool, item_hash)
	if item == null:
		ModLoaderLog.warning("Character preview: missing starting item/weapon hash=%d" % item_hash, "FengAddMods")
		return

	list_of_items.append(item)


# 原版 weapons / items 未初始化且不判空，缺资源时会在 append 处报错
func apply_objects_display(all_objects: Array, character: ItemParentData) -> void :
	var weapons: Array = []
	var items: Array = []

	if character != null:
		items.append(character)

	for object in all_objects:
		if object == null:
			continue

		if object is WeaponData:
			weapons.append(object)
		elif object is ItemData:
			items.append(object)

	apply_items_appearance(items)

