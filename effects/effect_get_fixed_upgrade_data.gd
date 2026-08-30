class_name GetFixedUpgradeData
extends Effect


var all_fixed_upgrade_id_hashs = []


func roll_fixed_upgrade():
    var upgrade_id = Utils.get_rand_element(ItemService.fengliu_get_all_upgrade_id_hashs())
    if upgrade_id in all_fixed_upgrade_id_hashs:
        roll_fixed_upgrade()
        return

    all_fixed_upgrade_id_hashs.append(upgrade_id)


func fengliu_roll_effecy(_player_index: int):
    for _index in range(4):
        roll_fixed_upgrade()


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back(self)
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase(self)


func get_args(_player_index: int) -> Array:
    if all_fixed_upgrade_id_hashs.size() == 0:
        return ["[color=lime]%s[/color]" % "?", "[color=lime]%s[/color]" % "?", "[color=lime]%s[/color]" % "?",  "[color=lime]%s[/color]" % "?"]
    
    var args = []
    for upgrade_id_hashs in all_fixed_upgrade_id_hashs:
        args.append("[color=lime]%s[/color]" % tr(Keys.hash_to_string[upgrade_id_hashs].to_upper()))

    return args
