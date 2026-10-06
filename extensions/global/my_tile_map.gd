extends "res://global/my_tile_map.gd"


const WholeImageBackground = preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_line_space/background_whole_image.gd")


# 覆盖: 原版铺格完成后，若背景开了「整张图」模式，则清掉拼贴格、改用整张场地图铺满场地
func init(zone: ZoneData) -> void :
	# 原版：逐格铺满 + 按场地尺寸设置 outline
	.init(zone)

	# 整张图模式：apply 内部会先清掉拼贴格，再把整张场地图按 cover 铺到场地范围
	WholeImageBackground.apply(self, RunData.get_background(), Rect2(0, 0, zone.width, zone.height), Utils.TILE_SIZE)

