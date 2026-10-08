extends "res://global/my_tile_map.gd"


const WholeImageBackground = preload("res://mods-unpacked/FengLiu-FengAddMods/zones/zone_line_space/background_whole_image.gd")


# 覆盖: 原版逐格铺满之后，若这个区域自持「整张图」背景（线条空间），就清掉拼贴格、改用整张场地图铺满场地。
func init(zone: ZoneData) -> void :
	# 原版：逐格铺满 + 按场地尺寸设置 outline
	.init(zone)

	# 本区域自持背景：把 RunData 当前背景也对齐过来，避免被全局「背景」设置或其它 mod 覆盖
	var whole_background = WholeImageBackground.get_zone_whole_background(zone)
	if whole_background != null and whole_background != RunData.get_background():
		RunData.current_background = whole_background

	# 整张图模式：apply 内部会先清掉拼贴格，再把整张场地图按 cover 铺到场地范围
	WholeImageBackground.apply(self, zone, Rect2(0, 0, zone.width, zone.height), Utils.TILE_SIZE)
