class_name VillagerNeutral
extends Neutral


var in_spawn_consumable = false


func take_damage(_value: int, args: TakeDamageArgs) -> Array:
    if in_spawn_consumable or args.hitbox == null or not "player_index" in args.hitbox.from or args.hitbox.from.player_index == - 1:
        return [0, 0, false]
    
    in_spawn_consumable = true
    var player_index = args.hitbox.from.player_index
    var item_count = FengLiuUtils.count_player_items(FengLiuKeys.item_emerald(), player_index)
    if item_count == 0:
        return [0, 0, false]
        
    var consumable = null
    var item_data = ItemService.get_item_from_id(FengLiuKeys.item_emerald())
    for _index in range(item_count):
        if Utils.get_chance_success(0.05):
            consumable = ItemService.get_consumable_for_tier(Tier.LEGENDARY)
        else:
            consumable = ItemService.get_consumable_for_tier(Tier.UNCOMMON)
        FengLiuUtils.spawn_consumable(consumable, global_position, 50, 500)
        RunData.remove_item(item_data, player_index)
    return [0, 0, false]