extends Area2D

export (float) var lifetime = 5.0

var _bodies: Array = []


func _ready() -> void:
	connect("body_entered", self, "_on_body_entered")
	connect("body_exited", self, "_on_body_exited")

	var timer = Timer.new()
	timer.wait_time = max(0.01, lifetime)
	timer.one_shot = true
	timer.connect("timeout", self, "_on_lifetime_timeout")
	add_child(timer)
	timer.start()


func setup(texture: Texture, p_scale: float, p_lifetime: float) -> void:
	if texture == null:
		return

	lifetime = p_lifetime

	$Sprite.texture = texture
	scale = Vector2(p_scale, p_scale)

	var tex_size = texture.get_size()
	var shape := RectangleShape2D.new()
	# 贴图四周有透明留白，碰撞区域按水洼主体缩小
	shape.extents = Vector2(tex_size.x * 0.40, tex_size.y * 0.30)
	$CollisionShape2D.shape = shape


func _on_lifetime_timeout() -> void:
	queue_free()


func _on_body_entered(body) -> void:
	if body == null or not body.has_method("fengliu_add_slippery_source"):
		return

	if not _bodies.has(body):
		_bodies.push_back(body)

	body.fengliu_add_slippery_source(get_instance_id())


func _on_body_exited(body) -> void:
	_bodies.erase(body)

	if body != null and body.has_method("fengliu_remove_slippery_source"):
		body.fengliu_remove_slippery_source(get_instance_id())


func _exit_tree() -> void:
	for body in _bodies:
		if is_instance_valid(body) and body.has_method("fengliu_remove_slippery_source"):
			body.fengliu_remove_slippery_source(get_instance_id())
