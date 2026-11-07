extends "res://singletons/player_run_data.gd"


# 基础盾值初始就有
const FENGLIU_SHIELD_BASE: = 5

var fengliu_shield_hash: int = Keys.generate_hash("stat_fengliu_shield")


func _init() -> void:
	._init()
	fengliu_apply_base_shield()
	fengliu_apply_effect_init_values()


# 与 init_effects() 同一时机：按各效果声明的初始值补齐效果槽
func fengliu_apply_effect_init_values() -> void:
	if ItemService == null:
		return

	ItemService.fengliu_apply_effect_init_values(effects)


func fengliu_apply_base_shield() -> void:
	if effects.get(fengliu_shield_hash, 0) < FENGLIU_SHIELD_BASE:
		effects[fengliu_shield_hash] = FENGLIU_SHIELD_BASE