extends "res://entities/gpe/petrol_puddle/petrol_puddle.gd"


# 机械泥潭尺寸：与酸液池、科技水枪共用 fengliu_puddle_size
func init(size: Vector2 = Vector2(1, 1)) -> void:
	var size_multiplier: float = Utils.get_fengliu_puddle_size_multiplier()
	.init(size * size_multiplier)
