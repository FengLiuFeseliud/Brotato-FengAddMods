extends "res://singletons/zone_service.gd"


# 覆盖: 玩家真正进入某个区域时（读档 / 开局 / 换区）再做一次区域下标自愈。
func set_current_zone(p_current_zone: ZoneData) -> void :
	.set_current_zone(p_current_zone)

	if ProgressData.has_method("fengliu_ensure_line_space_zone_last"):
		ProgressData.call("fengliu_ensure_line_space_zone_last", "set current zone")
