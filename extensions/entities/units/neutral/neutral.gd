extends Neutral


const DROP_STICK_ITEM = preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/items/stick/stick_data.tres")
const DROP_OAK_ITEM = preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/items/oak_log/oak_log_data.tres")

var effect_fengliu_minecraft = Keys.generate_hash("fengliu_minecraft")
var in_minecraft = false


func _ready():
    for player_index in RunData.get_player_count():
        if RunData.get_player_effect(effect_fengliu_minecraft, player_index).size() == 0:
            continue
        
        in_minecraft = true
        break


func die(args: = Utils.default_die_args) -> void :
    .die(args)

    if args.killed_by_player_index == -1 or not in_minecraft or self.get("drop_item") != null:
        return

    RunData.add_item(DROP_STICK_ITEM, args.killed_by_player_index)
    RunData.add_item(DROP_STICK_ITEM, args.killed_by_player_index)
    RunData.add_item(DROP_STICK_ITEM, args.killed_by_player_index)
    RunData.add_item(DROP_STICK_ITEM, args.killed_by_player_index)
    RunData.add_item(DROP_OAK_ITEM, args.killed_by_player_index)
