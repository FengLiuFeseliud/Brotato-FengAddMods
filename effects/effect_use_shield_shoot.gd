class_name UseShieldShoot
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：攻击消耗护盾
#   每次攻击都要先扣护盾，护盾为 0 时武器不再开火。
#   扣盾量：远程武器＝本次投射物数，其它武器＝1。
#   运行时 custom_key：fengliu_use_shield_shoot
# ------------------------------------------------------------
# 效果值：
#   key      未使用（留空）
#   value    未使用（留空，判定只看实例是否存在）
# ============================================================


static func get_id() -> String:
	return "fengliu_use_shield_shoot"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])