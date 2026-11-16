extends "res://ui/menus/shop/synergy_container.gd"


const FENGLIU_UNIQUE_SET_ID = "set_fengliu_unique"


# 独特套装的等级效果是空行，改为显示「只能拥有一把」的说明
func set_synergies_text(item_data: ItemParentData, player_index: int) -> void:
	.set_synergies_text(item_data, player_index)
	if not (item_data is WeaponData) or item_data.sets == null:
		return

	for i in item_data.sets.size():
		var item_set = item_data.sets[i]
		if item_set == null or item_set.my_id != FENGLIU_UNIQUE_SET_ID:
			continue
		if i >= synergy_panels.size():
			return

		var panel = synergy_panels[i]
		panel._plain_text = tr("WEAPON_CLASS_UNIQUE_DESCRIPTION")
		panel._synergy_effects.bbcode_text = panel._plain_text
		panel._resize_to_text()
