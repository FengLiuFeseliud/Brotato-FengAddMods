class_name FireExplodingEffect
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_exploding_effect.gd"


# ============================================================
# 效果：爆炸并留下火圈
#   触发方式与「爆炸」效果一致，区别是爆炸落点会留下一片持续燃烧的火；
#   火圈只对圈内敌人施加「点燃」，自身不造成任何直接伤害。
#   运行时 custom_key：无（沿用爆炸类效果的 key，如 effect_explode_custom）
# ------------------------------------------------------------
# 效果值：
#   chance                爆炸触发概率
#   explosion_scene       爆炸场景
#   scale                 爆炸范围倍率
#   fire_scale            火圈半径 = 爆炸实际半径 × 该倍率
#   fire_duration         火圈持续时间（秒）
#   fire_tick_interval    火圈点燃间隔（秒）
#   fire_particle_count   火圈火焰粒子数量
# ============================================================

export (float) var fire_scale = 0.75
export (float) var fire_duration = 4.0
export (float) var fire_tick_interval = 0.5
export (int) var fire_particle_count = 6


static func get_id() -> String:
	return "fengliu_fire_exploding"


func get_args(_player_index: int) -> Array:
	return ["%s%%" % str(round(chance * 100.0)), str(fire_duration)]