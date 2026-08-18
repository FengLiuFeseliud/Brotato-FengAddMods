extends "res://singletons/item_service.gd"


var effect_fengliu_can_all_drop_box = Keys.generate_hash("fengliu_can_all_drop_box")


static func get_dynamic_chance(init_chance: int, add_chance: int = 0, stat_count: int = 0) -> float:
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	if dynamic_chance > 100:
		return 100.0 / 100
		
	return dynamic_chance / 100


func get_consumable_to_drop(unit: Unit, item_chance: float) -> ConsumableData:
    var consumable = .get_consumable_to_drop(unit, item_chance)
    if consumable == null:
        return consumable

    if consumable.my_id_hash == Keys.consumable_item_box_hash or consumable.my_id_hash == Keys.consumable_legendary_item_box_hash:
        return consumable
    
    var effect = null
    var player_index = 0
    for _player_index in RunData.get_player_count():
        var effects = RunData.get_player_effect(effect_fengliu_can_all_drop_box, _player_index)
        if effects.size() == 0:
            continue
            
        player_index = _player_index
        effect = effects[0]
        break

    if effect == null:
        return consumable

    var tier = Tier.UNCOMMON
    var stat_count = 0
    if effect[1] != 0:
        stat_count = RunData.get_stat(effect[0], player_index)

    if Utils.get_chance_success(get_dynamic_chance(effect[2], effect[1], stat_count)):
        tier = Tier.LEGENDARY
    
    return get_consumable_for_tier(tier)