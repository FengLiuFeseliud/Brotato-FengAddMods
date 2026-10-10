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
	"effect_gain_stat_for_every_stat_full_shield": [0, 4],
	"effect_gain_stat_for_every_living_tree": [0, 4],
	"fengliu_wanted_item_tag_chance": [0],
	"effect_hit_shield_drop_consumable_value": [0],
	"fengliu_hit_shield_drop_consumable": [0],
	"accuracy": [0],
	"effect_add_gain_stat_after_remove_change": [5],
	"effect_add_gain_stat_after_remove_change_wave_max_gain": [5],
	"effect_add_stat_cap": [5],
	"effect_chance_apply_item_not_add_all_debuff_from_box": [0],
	"effect_boss_died_respawn": [1],
	"effect_box_stat": [0],
	"effect_burning_kill_extra_material": [0],
	"effect_can_all_drop_box": [0],
	"effect_can_swap_looter_enemies": [0],
	"effect_charm_enemy": [0, 2],
	"effect_chance_consumable_stat": [0, 1],
	"effect_consumable_stat": [1],
	"effect_extra_shop_item_chance": [1, 2],
	"effect_chance_gold_stats": [0, 1],
	"effect_item_bought_spawn_boss": [1, 2],
	"effect_kill_looter_spawn_boss": [0],
	"effect_picked_up_consumable_add_size": [0],
	"effect_regen_hit_protection": [0],
	"effect_random_shop_item_count_price": [3],
	"effect_stat_hit_protection": [2],
	"effect_stronger_aliens_on_aliens": [1],
	"effect_temporary_stats_stop": [1],
	"effect_turret_copy": [0],
	"effect_stat_gain_up_upgrade_data_tier": [0, 1],
	"effect_up_upgrade_data_tier": [1],
	"effect_wave_intensity_damage": [0],
	"effect_weapon_burn_damage": [0],
	"effect_relay": [0],
	"effect_weapon_shop_empty_slot_add_demage": [1],
	"effect_weapon_killed_health": [0],
	"effect_weapon_killed_loot": [1],
	"effect_weapon_killed_add_temp_stat": [0, 2],
	"effect_stat_for_every_character": [0, 2]
}


var fengliu_keys_needing_percent = {
	"accuracy": [0],
	"effect_add_gain_stat_after_remove_change": [5],
	"effect_chance_apply_item_not_add_all_debuff_from_box": [0],
	"effect_boss_died_respawn": [1],
	"effect_burning_kill_extra_material": [0],
	"effect_can_all_drop_box": [0],
	"effect_can_swap_looter_enemies": [0],
	"effect_charm_enemy": [0, 2],
	"effect_chance_consumable_stat": [0],
	"effect_extra_shop_item_chance": [1, 2],
	"effect_chance_gold_stats": [0],
	"effect_item_bought_spawn_boss": [1, 2],
	"effect_kill_looter_spawn_boss": [0],
	"effect_picked_up_consumable_add_size": [0],
	"effect_regen_hit_protection": [0],
	"effect_random_shop_item_count_price": [3],
	"effect_stronger_aliens_on_aliens": [1],
	"effect_turret_copy": [0],
	"effect_stat_gain_up_upgrade_data_tier": [0],
	"effect_wave_intensity_damage": [0],
	"effect_weapon_burn_damage": [0],
	"effect_relay": [0],
	"effect_weapon_killed_health": [0],
	"effect_weapon_killed_add_temp_stat": [0],
	"effect_add_random_character_to_shop": [0]
}


# 登记运算符
func _enter_tree() -> void:
	for key in fengliu_keys_needing_operator:
		if not keys_needing_operator.has(key):
			keys_needing_operator[key] = fengliu_keys_needing_operator[key]

	for key in fengliu_keys_needing_percent:
		if not keys_needing_percent.has(key):
			keys_needing_percent[key] = fengliu_keys_needing_percent[key]