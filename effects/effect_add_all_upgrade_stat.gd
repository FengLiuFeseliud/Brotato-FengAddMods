class_name AddAllUpgradeStat
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：获得全部升级项属性
#   获得该效果时，立即把指定品阶所有升级项的属性效果施加到玩家身上。
#   施加前会再按「升级属性加成」（level_upgrades_modifications）放大一次。
#   一次性永久生效，unapply 不回退。
#   运行时 custom_key：fengliu_add_all_upgrade_stat
# ------------------------------------------------------------
# 效果值：
#   value  升级项品阶（0=普通，1=罕见，2=稀有，3=传说），
#   key    不参与逻辑（留空即可）
# ============================================================


static func get_id() -> String:
	return "fengliu_add_all_upgrade_stat"


func apply(player_index: int) -> void:
    if value > 3:
        value = 3

    for upgrade_id_hashs in ItemService.fengliu_get_all_upgrade_id_hashs():
        var upgrade_data = ItemService.fengliu_get_upgrade_data(value, player_index, upgrade_id_hashs).duplicate()
        RunData.apply_item_effects(upgrade_data, player_index)


func unapply(_player_index: int) -> void:
	pass


func get_args(_player_index: int) -> Array:
    if value > 3:
        value = 3
    
    var text = ""
    if value == 0:
        text = "I"
    else:
        text = ItemService.get_tier_number(value)

    return ["[color=lime]%s[/color]" % text]
