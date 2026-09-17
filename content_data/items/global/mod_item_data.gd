class_name ModItemData
extends ItemData


export (bool) var one_elements = false
var is_box_get = false


func serialize() -> Dictionary:
	# 额外序列化「来自箱子」标记
	var serialized = .serialize()
	serialized.is_box_get = is_box_get
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	# 还原「来自箱子」标记，旧存档缺失时保持默认值
	.deserialize_and_merge(serialized)
	if serialized.has("is_box_get"):
		is_box_get = serialized.is_box_get
