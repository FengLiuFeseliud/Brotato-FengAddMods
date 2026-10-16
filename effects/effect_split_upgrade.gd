class_name SplitUpgrade
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：升级项一分为二
#   每次升级同时给一个「定向攻击升级项」与一个「定向生存升级项」，
#   替代原本的单个升级项。
#   运行时 custom_key：fengliu_split_upgrade
# ------------------------------------------------------------
# 效果值：
#   key      未使用（留空）
#   value    未使用（留空，判定只看实例是否存在）
# ============================================================


static func get_id() -> String:
	return "fengliu_split_upgrade"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])