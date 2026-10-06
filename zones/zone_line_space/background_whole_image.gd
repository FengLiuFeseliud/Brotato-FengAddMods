extends Reference

# 「线条空间」场地用「整张图」模式：把一整张场地图等比铺满给定区域（战斗场地与 HUD 小预览共用）。
# 由背景数据里的 fengliu_whole_image 开关控制；未启用时移除整图节点、回到原版按格拼贴。

const SPRITE_NAME = "FengliuWholeBackground"


# 当前背景是否要求整张图模式
static func is_enabled(background) -> bool:
	return background != null and ("fengliu_whole_image" in background) and background.fengliu_whole_image


# 移除整图节点（关闭整张图模式时调用）
static func clear(tilemap: TileMap) -> void:
	var sprite = tilemap.get_node_or_null(SPRITE_NAME)

	if sprite != null:
		sprite.queue_free()


# 把整张场地图铺到给定区域：清掉按格拼贴的格子，并让整图等比覆盖该区域（居中，超出裁掉）
static func apply(tilemap: TileMap, background, area_cells: Rect2, cell_size: int) -> void:
	if not is_enabled(background):
		clear(tilemap)
		return

	var texture: Texture = background.get_tiles_sprite()
	if texture == null:
		return

	# 先清掉原版铺的拼贴格，再用整图覆盖
	tilemap.clear()

	var sprite: Sprite = tilemap.get_node_or_null(SPRITE_NAME)
	if sprite == null:
		sprite = Sprite.new()
		sprite.name = SPRITE_NAME
		sprite.centered = false
		tilemap.add_child(sprite)

	var area_size: Vector2 = area_cells.size * cell_size
	var texture_size: Vector2 = texture.get_size()

	# 等比 cover：取较大的缩放系数，短边不留空
	var scale_factor: float = max(area_size.x / texture_size.x, area_size.y / texture_size.y)

	sprite.texture = texture
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.position = area_cells.position * cell_size + (area_size - texture_size * scale_factor) * 0.5
