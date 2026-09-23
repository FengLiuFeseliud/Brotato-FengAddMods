class_name BurningKillExtraMaterial
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：燃烧击杀额外掉落材料
#   燃烧击杀敌人时按「多重燃烧」概率额外掉落「材料」，
#   每 100% 多重燃烧再额外掉落一批
#   运行时 custom_key：fengliu_burning_kill_extra_material
# ------------------------------------------------------------
# 效果值：
#   value            燃烧击杀额外掉落的材料数量
# ============================================================

var fengliu_rekindling_hash = Keys.generate_hash("fengliu_rekindling")


static func get_id() -> String:
	return "fengliu_burning_kill_extra_material"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back([value])


func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([value])


func get_args(player_index: int) -> Array:
	# 取当前「多重燃烧」作为掉落概率，与效果值一起代入文案
	var rekindling: float = RunData.get_player_effect(fengliu_rekindling_hash, player_index)
	return [
		"[color=lime]%s%%[/color]" % rekindling,
		"[color=lime]%s[/color]" % value
	]
