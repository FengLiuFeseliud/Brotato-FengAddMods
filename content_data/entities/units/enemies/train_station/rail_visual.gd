extends Node2D

# 铁轨（火车站专用）：用「一段一段」的轨道贴图（rail_segment.png）沿横向与纵向两条线平铺，
# 交叉点即火车站坐标；本节点由 train_station.gd 挂到 Main 下、Entities 之前——
# 这样铁轨盖住地砖（TileMap，z=0）又压在单位之下，不会挡住车站与列车

export (Texture) var segment_texture
export (float) var segment_length = 112.0
export (float) var segment_scale = 0.65

var _fengliu_sprites: Array = []


func _fengliu_build(center: Vector2) -> void :
	# 以 center 为交叉点铺满整个场地：横向沿 x 平铺、纵向沿 y 平铺（同一贴图旋转 90°）
	_fengliu_clear()
	if segment_texture == null or segment_length <= 0.0:
		return

	var zone_rect: Rect2 = ZoneService.get_current_zone_rect()
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return

	var tex_width: float = max(float(segment_texture.get_width()), 1.0)
	var count_x: int = int(ceil(zone_rect.size.x / segment_length))
	var step_x: float = zone_rect.size.x / float(count_x)
	for i in count_x:
		_fengliu_add_sprite(Vector2( zone_rect.position.x + step_x * (float(i) + 0.5), center.y ), 0.0, step_x / tex_width)
	
	var count_y: int = int(ceil(zone_rect.size.y / segment_length))
	var step_y: float = zone_rect.size.y / float(count_y)
	for i in count_y:
		_fengliu_add_sprite(Vector2( center.x, zone_rect.position.y + step_y * (float(i) + 0.5) ), PI * 0.5, step_y / tex_width)


func _fengliu_add_sprite(world_position: Vector2, rotation_rad: float, along_scale: float) -> void :
	# 贴图锚点在中心：旋转 90° 后横向段就变成纵向段；along_scale 只沿轨方向缩放
	var sprite: Sprite = Sprite.new()
	sprite.texture = segment_texture
	sprite.centered = true
	sprite.rotation = rotation_rad
	sprite.scale = Vector2( along_scale, segment_scale )
	sprite.position = to_local(world_position)
	add_child(sprite)
	_fengliu_sprites.push_back(sprite)


func _fengliu_set_alpha(alpha: float) -> void :
	# 淡出：整条铁轨统一改透明度
	modulate = Color( 1, 1, 1, clamp(alpha, 0.0, 1.0) )


func _fengliu_clear() -> void :
	# 清掉已铺的段（重建 / 池复用重置时调用）
	for sprite in _fengliu_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
			
	_fengliu_sprites = []

