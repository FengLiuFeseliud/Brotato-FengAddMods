extends "res://singletons/text.gd"


var fengliu_keys_needing_operator = {
	"stat_fengliu_shield": [0], 
	"info_pos_stat_fengliu_shield": [0], 
	"info_neg_stat_fengliu_shield": [0],
	"effect_consumable_shield_regen_value": [0],
	"fengliu_bullet_scale": [0],
	"effect_tree_drop_double_value": [0],
	"effect_rekindling_value": [0],
	"effect_reduce_shield_damage_value": [0],
	"effect_gain_stat_for_every_stat_full_shield": [0],
	"effect_gain_stat_for_every_living_tree": [0],
	"fengliu_wanted_item_tag_chance": [0],
	"effect_hit_shield_drop_consumable_value": [0],
	"fengliu_hit_shield_drop_consumable": [0],
	"accuracy": [0],
	"effect_extra_shop_item_chance": [1,2]
}


var fengliu_keys_needing_percent = {
	"accuracy": [0],
	"effect_extra_shop_item_chance": [1,2]
}


# 登记运算符
func _enter_tree() -> void:
	for key in fengliu_keys_needing_operator:
		if not keys_needing_operator.has(key):
			keys_needing_operator[key] = fengliu_keys_needing_operator[key]

	for key in fengliu_keys_needing_percent:
		if not keys_needing_percent.has(key):
			keys_needing_percent[key] = fengliu_keys_needing_percent[key]