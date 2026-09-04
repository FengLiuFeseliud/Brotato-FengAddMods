class_name ModItemData
extends ItemData


export (bool) var one_elements = false
var is_box_get = false


func serialize() -> Dictionary:
	var serialized = .serialize()
	serialized.is_box_get = is_box_get
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	if serialized.has("is_box_get"):
		is_box_get = serialized.is_box_get
