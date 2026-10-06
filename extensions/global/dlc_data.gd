extends "res://global/dlc_data.gd"


var _fengliu_dlc_resources_registered: bool = false
var _fengliu_zone_index_before_remove: int = -1


# 覆盖: 原版 add_resources 是纯 append、没有任何幂等保护，而启动期会被调用多次
#  ⇒ 重复调用会让同一份 DLC 的区域/背景/boss/精英在列表里出现多份（实测「深渊」出现 3 次）
func add_resources():
	# 幂等：已注册过就直接返回（原版没有这层保护，重复调用会追加出多份区域/背景）
	if _fengliu_dlc_resources_registered:
		return

	_fengliu_dlc_resources_registered = true
	.add_resources()

	# 原版是纯 append，这里把区域放回移除前的下标
	_fengliu_restore_zone_index()


# 覆盖: 反注册后清标记（保证 remove→add 流程仍能重新注册），并记下移除前的下标供放回原位
func remove_resources():
	# 记下移除前的下标：add 是纯 append，要靠它把区域放回原位
	for zone in zones:
		_fengliu_zone_index_before_remove = ZoneService.zones.find(zone)

	.remove_resources()

	_fengliu_dlc_resources_registered = false


# 把本数据的区域放回移除前的下标：原版 remove→add 成对流程（RunData.reset 等）会把区域挪到列表末尾，
# 而原版按下标取区域（zone.my_id 必须等于下标），位置被挪动会连累其它区域的下标
func _fengliu_restore_zone_index() -> void:
	if _fengliu_zone_index_before_remove < 0:
		return

	for zone in zones:
		var current_index: int = ZoneService.zones.find(zone)

		# 找不到（被别的流程摘掉）或本来就在原位就不动
		if current_index >= 0 and current_index != _fengliu_zone_index_before_remove:
			ZoneService.zones.remove(current_index)
			ZoneService.zones.insert(min(_fengliu_zone_index_before_remove, ZoneService.zones.size()), zone)

	_fengliu_zone_index_before_remove = -1
