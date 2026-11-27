extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_null_effect.gd"


# ============================================================
# 效果：击杀冰冻敌人后发射子弹
#   用该武器击杀处于冰冻状态的敌人时，从尸体位置发射 value 发子弹。
#   子弹属性由 weapon_stats 决定（伤害 = 基础伤害 + 缩放属性）。
#   同原版「长胡子的婴儿」：子弹 stats 只初始化一次并缓存，属性刷新时重建。
#   运行时 custom_key：fengliu_frozen_kill_projectile
# ------------------------------------------------------------
# 效果值：
#   value              子弹数量
#   weapon_stats       子弹（远程武器）属性
#   auto_target_enemy  是否自动瞄准敌人
# ============================================================

export (Resource) var weapon_stats
export (bool) var auto_target_enemy = false


static func get_id() -> String:
	return "fengliu_frozen_kill_projectile"


func get_args(player_index: int) -> Array:
	if weapon_stats == null:
		return [str(value), "0", ""]

	var current_stats = WeaponService.init_ranged_stats(weapon_stats, player_index, true)
	var scaling_text: String = WeaponService.get_scaling_stats_icon_text(weapon_stats.scaling_stats)
	return [str(value), str(current_stats.damage), scaling_text]
