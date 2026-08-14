class_name ItemBoughtSpawnBoss
extends Effect


export (int) var bought_add_chance = 0


func get_item_count(player_index: int) -> int:
	var count = 0
	for item in RunData.get_player_items(player_index):
		if item.my_id_hash == key_hash:
			count += 1
	return count


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, bought_add_chance])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, bought_add_chance])


func get_args(player_index: int) -> Array:
    var args = .get_args(player_index)

    var chance = 0
    if bought_add_chance != 0:
        chance = value + get_item_count(player_index) * (bought_add_chance / 100.0)
    return [
		args[1],
		"[color=lime]%s%%[/color]" % chance,
        "[color=lime]%s%%[/color]" % bought_add_chance
	]