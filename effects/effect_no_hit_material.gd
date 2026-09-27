class_name NoHitMaterial
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：未受伤奖励材料
#   连续「wait_time」秒没有受伤（盾也没被消耗）时获得「value」点材料，
#   受伤立刻重新计时；计时器与结算点见扩展脚本
#   extensions/entities/units/player/player.gd 的未受伤材料计时块。
#   运行时 custom_key：fengliu_no_hit_material
# ------------------------------------------------------------
# 效果值：
#   wait_time     未受伤多久算一轮（秒）
#   value         每轮获得的材料数
#   tracking_key  追踪键（填道具 id，空则不累计）
# ============================================================

export (int) var wait_time = 10
export (String) var tracking_key = ""


static func get_id() -> String:
	return "fengliu_no_hit_material"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back(self)


func unapply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).erase(self)


func get_args(player_index: int) -> Array:
	# 按顺序填充描述文本 {0} {1} 占位符：未受伤秒数、每轮材料数
	return [
		str(wait_time),
		"[color=lime]%s[/color]" % value
	]
