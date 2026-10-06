extends "res://global/dlc_data.gd"


var _fengliu_dlc_resources_registered: bool = false
var _fengliu_zone_index_before_remove: int = -1


func add_resources():
	if _fengliu_dlc_resources_registered:
		return

	_fengliu_dlc_resources_registered = true
	.add_resources()

	# 原版是纯 append，这里把区域放回移除前的下标
	_fengliu_restore_zone_index()


func remove_resources():
	for zone in zones:
		_fengliu_zone_index_before_remove = ZoneService.zones.find(zone)

	.remove_resources()

	_fengliu_dlc_resources_registered = false


# 把本数据的区域放回移除前的下标
func _fengliu_restore_zone_index() -> void:
	if _fengliu_zone_index_before_remove < 0:
		return

	for zone in zones:
		var current_index: int = ZoneService.zones.find(zone)

		if current_index >= 0 and current_index != _fengliu_zone_index_before_remove:
			ZoneService.zones.remove(current_index)
			ZoneService.zones.insert(min(_fengliu_zone_index_before_remove, ZoneService.zones.size()), zone)

	_fengliu_zone_index_before_remove = -1
