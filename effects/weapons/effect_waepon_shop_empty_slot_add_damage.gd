class_name WeaponShopEmptySlotAddDamage
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_null_effect.gd"


# ============================================================
# 效果：商店空位增伤
#   开始敌袭前，商店每空一个位子就为本武器增加基础伤害。
#   空位数按存档里的商店道具数量实时计算。
#   运行时 custom_key：fengliu_waepon_shop_empty_slot_add_damage
# ------------------------------------------------------------
# 效果值：
#   value   每个空位增加的基础伤害
# ============================================================


static func get_id() -> String:
	return "fengliu_waepon_shop_empty_slot_add_damage"


func get_add_damage(player_index: int) -> int:
    # 读不到存档状态时返回 -1（加成按 0 处理、说明文本显示 ?）
    var saved_run_state = ProgressData.saved_run_state
    if saved_run_state == null:
        return -1

    # 存档里还没有商店记录时视为商店全空
    if not saved_run_state.has("shop_items"):
        return ItemService.NB_SHOP_ITEMS * value

    # 空位数 = 商店总位数 - 当前剩余道具数
    return (ItemService.NB_SHOP_ITEMS - saved_run_state["shop_items"][player_index].size()) * value


func get_args(player_index: int) -> Array:
    # 拿不到空位数据时用 ? 占位
    var add_damage = get_add_damage(player_index)
    if add_damage < 0:
        add_damage = "?"

    # 返回 [每个空位的基础伤害, 当前空位累计的加成]
    return [
        str(value),
        "[color=lime]%s[/color]" % add_damage
    ]