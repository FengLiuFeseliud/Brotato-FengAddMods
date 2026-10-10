class_name PendingNotice
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：未生效提示
#   仅作为商店待生效角色描述里的一行文字（运行时由代码构造实例，从不 apply）。
#   运行时 custom_key：fengliu_pending_notice
# ------------------------------------------------------------
# 效果值：
#   key    未使用
#   value  未使用
# ============================================================


static func get_id() -> String:
	return "fengliu_pending_notice"


func apply(_player_index: int) -> void:
	pass


func unapply(_player_index: int) -> void:
	pass


func get_args(_player_index: int) -> Array:
	return []
