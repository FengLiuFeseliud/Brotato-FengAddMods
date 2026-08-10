class_name DropItemNeutral
extends Neutral


export (Resource) var drop_item
export (String) var drop_item_weapon_id
export (int) var drop_item_tier = 0


func take_damage(value: int, args: TakeDamageArgs) -> Array:
    if args.hitbox == null or not "weapon_id" in args.hitbox.from:
        return [0, 0, false]
        
    if args.hitbox.from.weapon_id == null or drop_item_weapon_id == null:
        return .take_damage(value, args)
    
    if args.hitbox.from.weapon_id != drop_item_weapon_id:
        return [0, 0, false]
    
    if  args.hitbox.from.tier < drop_item_tier:
        return [0, 0, false]
    
    return .take_damage(value, args)


func die(args: = Utils.default_die_args) -> void :
    .die(args)

    if drop_item == null or args.killed_by_player_index == -1:
        return

    RunData.add_item(drop_item, args.killed_by_player_index)