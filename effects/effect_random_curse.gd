class_name RandomCurse
extends Effect


export (int) var need_level = 0
export (Array) var not_curse_item_ids = []
var not_curse_item_ids_hash = []


func _generate_hashes() -> void:
    ._generate_hashes()
    for not_curse_item_id in not_curse_item_ids:
        not_curse_item_ids_hash.append(Keys.generate_hash(not_curse_item_id))


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, need_level, not_curse_item_ids_hash])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, need_level, not_curse_item_ids_hash])


func get_args(player_index: int) -> Array:
    var args = .get_args(player_index)
    return [
        args[0],
        args[1],
        str(need_level)
    ]