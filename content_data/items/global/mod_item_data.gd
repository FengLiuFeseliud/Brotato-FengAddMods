class_name ModItemData
extends ItemData


export (bool) var one_elements = false
export (bool) var is_hit_lost_item = false
export (bool) var hide_in_codex = false
var is_box_get = false


func serialize() -> Dictionary:
	# 额外序列化「来自箱子」标记
	var serialized = .serialize()
	serialized.is_box_get = is_box_get
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	is_box_get = serialized.is_box_get if "is_box_get" in serialized else false
