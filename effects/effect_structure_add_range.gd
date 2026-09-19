class_name StructureAddRange
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：构造物增加射程
#   给所有构造物增加射程，增加量来自某属性。
#   运行时 custom_key：fengliu_structure_add_range
# ------------------------------------------------------------
# 效果值：
#   key    用于增加射程的属性
#   value  （参与存储，射程 = 基础射程 + 该属性值）
# ============================================================


static func get_id() -> String:
	return "fengliu_structure_add_range"

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])
