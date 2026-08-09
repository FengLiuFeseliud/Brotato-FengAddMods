class_name DropItemNeutral
extends Neutral


export (Resource) var drop_item


func die(args: = Utils.default_die_args) -> void :
    .die(args)

    if drop_item == null or args.killed_by_player_index == -1:
        return

    RunData.add_item(drop_item, args.killed_by_player_index)