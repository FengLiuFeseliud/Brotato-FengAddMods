extends "res://ui/menus/shop/stats_container.gd"


const FENGLIU_MOD_ID = "FengAddMods"


# 扩展初始化
func _ready() -> void:
	if _secondary_stats.get_child_count() == 0:
		ModLoaderLog.error("No row to duplicate in SecondaryStats, extra stats skipped.", FENGLIU_MOD_ID)
		return

	var row_template = _secondary_stats.get_child(0)
	for stat_key in RunData.FENGLIU_EXTRA_SECONDARY_STAT_KEYS:
		var row = row_template.duplicate()
		row.key = stat_key.to_upper()
		row.custom_text_key = ""
		row.reverse = false
		_secondary_stats.add_child(row)
		row.disable_focus()
		secondary_stats.append(row)
