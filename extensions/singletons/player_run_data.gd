extends "res://singletons/player_run_data.gd"


# 基础盾值初始就有
const FENGLIU_SHIELD_BASE: = 5

var fengliu_shield_hash: int = Keys.generate_hash("stat_fengliu_shield")


func _init() -> void:
	._init()
	fengliu_apply_base_shield()


func fengliu_apply_base_shield() -> void:
	if effects.get(fengliu_shield_hash, 0) < FENGLIU_SHIELD_BASE:
		effects[fengliu_shield_hash] = FENGLIU_SHIELD_BASE