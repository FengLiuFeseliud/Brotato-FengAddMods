extends "res://singletons/text.gd"


var fengliu_keys_needing_operator = [
	"stat_fengliu_shield", 
	"info_pos_stat_fengliu_shield", 
	"info_neg_stat_fengliu_shield",
	"effect_consumable_shield_regen_value",
	"fengliu_bullet_scale",
	"effect_tree_drop_double_value",
	"effect_rekindling_value",
	"effect_reduce_shield_damage_value",
	"effect_gain_stat_for_every_stat_full_shield"
]


# 登记运算符
func _enter_tree() -> void:
	for key in fengliu_keys_needing_operator:
		if not keys_needing_operator.has(key):
			keys_needing_operator[key] = [0]
