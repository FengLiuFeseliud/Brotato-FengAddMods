class_name VillagerNeutral
extends Neutral


var item_emerald = Keys.generate_hash("item_emerald")
var in_spawn_consumable = false


func get_item_count(item_hash: int, player_index: int) -> int:
	var count = 0
    
	for item in RunData.get_player_items(player_index):
		if item.my_id_hash == item_hash:
			count += 1
            
	return count


func spawn_consumable(spawn_pos: Vector2, consumable_data: ConsumableData) -> void:
    var main = get_tree().current_scene

    var consumable = main.get_node_from_pool(main._consumable_pool_id, main._consumables_container)
    if consumable == null:
        consumable = main.consumable_scene.instance()
        main._consumables_container.call_deferred("add_child", consumable)
        var _error = consumable.connect("picked_up", main, "on_consumable_picked_up")
        yield(consumable, "ready") 
        
    consumable.already_picked_up = false
    consumable.consumable_data = consumable_data
    consumable.set_texture(consumable_data.icon)
    
    var dist = rand_range(50, 500) 
    var push_back_destination = ZoneService.get_rand_pos_in_area(spawn_pos, dist, 0)
    consumable.drop(spawn_pos, 0, push_back_destination)
    
    main._consumables.push_back(consumable)


func take_damage(_value: int, args: TakeDamageArgs) -> Array:
    if in_spawn_consumable or args.hitbox == null or not "player_index" in args.hitbox.from or args.hitbox.from.player_index == - 1:
        return [0, 0, false]
    
    in_spawn_consumable = true
    var player_index = args.hitbox.from.player_index
    var item_count = get_item_count(item_emerald, player_index)
    if item_count == 0:
        return [0, 0, false]
        
    var consumable = null
    var item_data = ItemService.get_item_from_id(item_emerald)
    for _index in range(item_count):
        if Utils.get_chance_success(0.05):
            consumable = ItemService.get_consumable_for_tier(Tier.LEGENDARY)
        else:
            consumable = ItemService.get_consumable_for_tier(Tier.UNCOMMON)
        spawn_consumable(global_position, consumable)
        RunData.remove_item(item_data, player_index)
    return [0, 0, false]