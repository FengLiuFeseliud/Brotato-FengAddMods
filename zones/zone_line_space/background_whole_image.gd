extends Reference

# 「线条空间」场地用「整张图」模式：把一整张场地图等比铺满给定区域（战斗场地与 HUD 小预览共用）。
# 只认「本区域自持的那张背景」（get_zone_whole_background / resolve_background），其它区域与背景一律走原版
# ⇒ 本 mod 不会影响任何别的区域（原版 my_tile_map 对所有区域都会走到这里，必须严格限定）。

const SPRITE_NAME = "FengliuWholeBackground"
const LOG_ID = "FengAddMods"


# 对象是否带某属性：用属性表判断（`in` 对 Resource 的语义在不同挂载环境[目录/zip]不保证一致）
static func has_property(object, property_name: String) -> bool:
	if object == null:
		return false

	for property in object.get_property_list():
		if property.name == property_name:
			return true

	return false


# 当前背景是否要求整张图模式
static func is_enabled(background) -> bool:
	return has_property(background, "fengliu_whole_image") and background.fengliu_whole_image


# 某个区域是否自持整图背景：它的 default_backgrounds 里有开开关的那张
static func get_zone_whole_background(zone):
	if not has_property(zone, "default_backgrounds"):
		return null

	for background in zone.default_backgrounds:
		if is_enabled(background):
			return background

	return null


# 该区域这一局该用哪张背景：区域自持整图背景时优先用它（不受全局「背景」设置与其它 mod 影响）
static func resolve_background(zone):
	var zone_background = get_zone_whole_background(zone)

	if zone_background != null:
		return zone_background

	return RunData.get_background()



# 移除整图节点（关闭整张图模式时调用）
static func clear(tilemap: TileMap) -> void:
	var sprite = tilemap.get_node_or_null(SPRITE_NAME)

	if sprite != null:
		sprite.queue_free()


# 把整张场地图铺到给定区域：清掉按格拼贴的格子，并让整图等比覆盖该区域（居中，超出裁掉）
static func apply(tilemap: TileMap, zone, area_cells: Rect2, cell_size: int) -> void:
	var zone_name: String = str(zone.name) if zone != null else "<null>"
	var background = resolve_background(zone)

	if not is_enabled(background):
		# 常驻诊断（每次进区域 1 行）：说明这次为什么没铺整图，便于排查「场地图没了」
		ModLoaderLog.info("Whole background skipped: zone=%s background=%s" % [zone_name, str(background.name) if background != null else "<null>"], LOG_ID)
		clear(tilemap)
		return

	var texture: Texture = background.get_tiles_sprite()
	if texture == null:
		ModLoaderLog.warning("Whole background has no texture: zone=%s background=%s" % [zone_name, str(background.name)], LOG_ID)
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

	# 常驻诊断（每次进区域 1 行）：实际铺了什么图、什么尺寸、保留了多少拼贴格
	ModLoaderLog.info("Whole background applied: zone=%s background=%s texture=%s size=%s sprite_scale=%s cells=%d" % [zone_name, str(background.name), str(texture.resource_path), str(texture_size), str(sprite.scale), tilemap.get_used_cells().size()], LOG_ID)


# 捕获「场景烘焙」的预览格（pos → autotile 坐标）
#   原版 character_panel_ui.gd::_update_bg() 只改贴图、不重建格子，格子来自 .tscn 里烘焙的 tile_data
#   ⇒ 清掉后原版不会恢复 ⇒ 本 mod 在预览里"隐藏"格子的同时必须先存，之后给别的区域铺回来。
static func capture_baked_cells(tilemap: TileMap) -> Dictionary:
	var cells: Dictionary = {}

	if tilemap == null:
		return cells

	for cell in tilemap.get_used_cells():
		cells[cell] = tilemap.get_cell_autotile_coord(cell.x, cell.y)

	return cells


# 把捕获到的格铺回去
static func restore_baked_cells(tilemap: TileMap, cells: Dictionary) -> void:
	if tilemap == null:
		return

	for cell in cells.keys():
		tilemap.set_cell(cell.x, cell.y, 0, false, false, false, cells[cell])
