class_name ResetItemStat
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：道具属性改写
#   商店生成道具副本时，把「{0}」相关的道具效果整体改指向「{1}」。
#   只改副本，不动商店池里的模板资源。
#   运行时 custom_key：fengliu_reset_item_stat
# ------------------------------------------------------------
# 效果值：
#   key       被改写的属性 id
#   to_stat   改写后的属性 id
# ============================================================


export (String) var to_stat = ""
var to_stat_hash = Keys.empty_hash


static func get_id() -> String:
	return "fengliu_reset_item_stat"


func _generate_hashes() -> void:
	._generate_hashes()
	to_stat_hash = Keys.generate_hash(to_stat)


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, to_stat_hash])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, to_stat_hash])


func get_args(_player_index: int) -> Array:
    return [
		"[color=lime]%s[/color]" % tr(key.to_upper()), 
		"[color=lime]%s[/color]" % tr(to_stat.to_upper())
	]