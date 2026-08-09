extends Neutral


var effect_minecraft = Keys.generate_hash("minecraft")
var in_minecraft = false
var _drop_stick_item = preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/items/stick/stick_data.tres")


func _ready():
    for player_index in RunData.get_player_count():
        if RunData.get_player_effect(effect_minecraft, player_index).size() == 0:
            continue
        
        in_minecraft = true
        break


func die(args: = Utils.default_die_args) -> void :
    .die(args)

    if args.killed_by_player_index == -1 or not in_minecraft or self.get("drop_item") != null:
        return

    RunData.add_item(_drop_stick_item, args.killed_by_player_index)
    RunData.add_item(_drop_stick_item, args.killed_by_player_index)
    RunData.add_item(_drop_stick_item, args.killed_by_player_index)
    RunData.add_item(_drop_stick_item, args.killed_by_player_index)
