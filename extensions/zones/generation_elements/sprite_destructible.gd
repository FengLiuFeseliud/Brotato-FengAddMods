extends 'res://zones/generation_elements/sprite_destructible.gd'


func fengliu_apply_range_state() -> void:
	if not is_inside_tree():
		return
	if area2d == null or not area2d.monitoring:
		return

	destroy_sprite()
