class_name KilledRegenShield
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：击杀回盾
#   「罐头」专用：击杀敌人时给该玩家恢复护盾；多个实例的数值会先
#   求和，再由玩家侧统一走上限夹取与结算。
#   运行时 custom_key：fengliu_killed_regen_shield
# ------------------------------------------------------------
# 效果值：
#   key      未使用（留空）
#   value    每次击杀恢复的护盾值
# ============================================================


static func get_id() -> String:
	return "fengliu_killed_regen_shield"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])