class_name ShieldNotRegen
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：护盾不再恢复
#   拥有后，护盾的一切恢复途径（自动回盾、消耗品回盾等）全部失效。
#   判定点见扩展脚本 extensions/entities/units/player/player.gd 的
#   fengliu_shield_regen。
#   运行时 custom_key：fengliu_shield_not_regen
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑
# ============================================================


static func get_id() -> String:
	return "fengliu_shield_not_regen"


func fengliu_get_effect_init_value():
	return 0


func apply(player_index: int) -> void:
	# 计数 +1
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = effects.get(custom_key_hash, 0) + 1


func unapply(player_index: int) -> void:
	# 计数 -1，下限 0
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = max(0, effects.get(custom_key_hash, 0) - 1)
