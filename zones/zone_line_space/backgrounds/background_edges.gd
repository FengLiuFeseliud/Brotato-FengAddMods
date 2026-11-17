extends Node2D

# 场地四边背景条带：用 6 张静态段贴图（edge_segments/edge_segment_1..6.png，250×250）沿边随机拼接
# 贴图统一是「横版」：一条居中横主线 + 线上方点阵；下边 flip_v、左右两条旋转 ±90° ⇒ 点阵始终朝场外
# 每段只沿段方向随机镜像（垂直方向不随机翻）；节点挂 TileMap 下（背景之上、单位之下）

const SEGMENT_DIR = "res://mods-unpacked/FengLiu-FengAddMods/zones/zone_line_space/backgrounds/edge_segments/"
const SEGMENT_COUNT = 6
const LOG_ID = "FengAddMods"

export (int) var segment_length = 250
export (int) var strip_thickness = 250
export (int) var variant_count = 6
export (int) var strip_offset = - 95
export (float) var strip_alpha = 0.85

var _fengliu_strips: Array = []
var _fengliu_textures: Array = []


func _fengliu_rebuild(zone_rect: Rect2, tile: int) -> void :
	# 四条边各自从 6 张静态贴图里随机挑选拼接；段数按地图尺寸自动算
	_fengliu_clear()
	if variant_count <= 0 or segment_length <= 0:
		return
	var seg: float = float(max(segment_length, 16))
	var thickness: float = float(max(strip_thickness, 16))
	var offset: float = float(strip_offset)
	var outside: float = thickness + offset
	# 四条边只铺「相邻两条带的内沿之间」，四个角留白（每角 250×250：95 场内 + 155 场外；整体外移 30）
	var inner_left: float = zone_rect.position.x - offset
	var inner_right: float = zone_rect.end.x + offset
	var inner_top: float = zone_rect.position.y - offset
	var inner_bottom: float = zone_rect.end.y + offset
	seed(RunData.current_wave * 7919 + 31)
	# 上边：不旋转、点阵朝上；下边：flip_v 让点阵朝下
	_fengliu_build_side(inner_left, zone_rect.position.y - outside, inner_right - inner_left, true, seg, thickness, 0.0, false)
	_fengliu_build_side(inner_left, zone_rect.end.y + offset, inner_right - inner_left, true, seg, thickness, 0.0, true)
	# 左边：逆时针 90°（点阵朝左）；右边：顺时针 90°（点阵朝右）
	_fengliu_build_side(inner_top, zone_rect.position.x - outside, inner_bottom - inner_top, false, seg, thickness, - 90.0, false)
	_fengliu_build_side(inner_top, zone_rect.end.x + offset, inner_bottom - inner_top, false, seg, thickness, 90.0, false)
	randomize()


func _fengliu_build_side(along_start: float, cross: float, length: float, horizontal: bool, seg: float, thickness: float, rotation_deg: float, flip_across: bool) -> void :
	# 按可用跨度均分：count 段正好铺满 [along_start, along_start + length]，不越界、不与相邻条带重叠
	var count: int = int(ceil(length / seg))
	var step: float = length / float(max(count, 1))
	var cursor: float = along_start
	for _index in count:
		var texture: Texture = _fengliu_segment_texture(randi() % variant_count)
		if texture == null:
			return
		# 目标框（世界方向）与贴图框（贴图固定是横版：段长 × 厚度，段长按跨度均分后可能轻微缩放）
		var target_pos: Vector2 = Vector2( cursor, cross ) if horizontal else Vector2( cross, cursor )
		var target_size: Vector2 = Vector2( step, thickness ) if horizontal else Vector2( thickness, step )
		var texture_size: Vector2 = Vector2( step, thickness )
		# 只沿段方向随机镜像（垂直方向必须保持朝外，不能被随机翻）
		var flip_along: bool = randf() < 0.5
		_fengliu_add_segment(texture, target_pos + target_size * 0.5, texture_size, flip_along, flip_across, rotation_deg)
		cursor += step


func _fengliu_add_segment(texture: Texture, center: Vector2, texture_size: Vector2, flip_along: bool, flip_across: bool, rotation_deg: float) -> void :
	# 一段条带：贴图按自身尺寸排、绕中心旋转，旋转后正好占满目标框
	var strip: TextureRect = TextureRect.new()
	strip.texture = texture
	strip.expand = true
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.rect_size = texture_size
	strip.rect_pivot_offset = texture_size * 0.5
	strip.rect_rotation = rotation_deg
	strip.rect_position = center - texture_size * 0.5
	strip.flip_h = flip_along
	strip.flip_v = flip_across
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.modulate = Color( 1, 1, 1, strip_alpha )
	add_child(strip)
	_fengliu_strips.push_back(strip)


func _fengliu_segment_texture(variant: int) -> Texture :
	# 6 张静态段贴图（首次使用时加载并缓存）；缺图时跳过该变体
	if _fengliu_textures.empty():
		for index in SEGMENT_COUNT:
			var path: String = SEGMENT_DIR + "edge_segment_" + str(index + 1) + ".png"
			var texture = load(path)
			if texture == null:
				ModLoaderLog.warning("Edge segment texture missing: %s" % path, LOG_ID)
				continue
			_fengliu_textures.push_back(texture)
		if _fengliu_textures.empty():
			return null
	return _fengliu_textures[variant % _fengliu_textures.size()]


func _fengliu_clear() -> void :
	# 清掉已铺的段（重建 / 关闭整图背景时调用）
	for strip in _fengliu_strips:
		if is_instance_valid(strip):
			# 立刻从树上摘掉（queue_free 要到帧末才生效，同期重建会看到旧段）
			remove_child(strip)
			strip.queue_free()
	_fengliu_strips = []
