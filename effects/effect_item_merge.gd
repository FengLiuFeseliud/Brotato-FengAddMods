class_name ItemMerge
extends Effect


export (int) var merge_from_count = 0
export (String) var merge_from_item
export (String) var merge_to_item
export (int) var merge_to_item_count = 1
var merge_from_item_hash = Keys.empty_hash
var merge_to_item_hash = Keys.empty_hash


func _generate_hashes() -> void:
    ._generate_hashes()
    merge_from_item_hash = Keys.generate_hash(merge_from_item)
    merge_to_item_hash = Keys.generate_hash(merge_to_item)


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, merge_from_item_hash, merge_from_count, merge_to_item_hash, merge_to_item_count])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, merge_from_item_hash, merge_from_count, merge_to_item_hash, merge_to_item_count])


func get_args(player_index: int) -> Array:
    var args = .get_args(player_index)
    return [
        args[0],
        tr(merge_from_item.to_upper()),
        str(merge_from_count)
    ]