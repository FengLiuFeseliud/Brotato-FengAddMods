class_name WeaponShopEmptySlotAddDamage
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_null_effect.gd"


static func get_id() -> String:
	return "fengliu_waepon_shop_empty_slot_add_damage"


func get_add_damage(player_index: int) -> int:
    var saved_run_state = ProgressData.saved_run_state
    if saved_run_state == null:
        return -1

    if not saved_run_state.has("shop_items"):
        return ItemService.NB_SHOP_ITEMS * value

    return (ItemService.NB_SHOP_ITEMS - saved_run_state["shop_items"][player_index].size()) * value


func get_args(player_index: int) -> Array:
    var add_damage = get_add_damage(player_index)
    if add_damage < 0:
        add_damage = "?"

    return [
        str(value),
        "[color=lime]%s[/color]" % add_damage
    ]