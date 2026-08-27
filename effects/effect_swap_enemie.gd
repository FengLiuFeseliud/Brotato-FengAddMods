class_name SwapEnemies
extends Effect


# ============================================================
# 效果：敌人替换（天气预报）
#   下一波敌袭时，随机选择两种敌人，将其中一种替换为另一种；
#   每次进入商店刷新时重新随机「预报」。
#   运行时 custom_key：fengliu_swap_enemie
# ------------------------------------------------------------
# 效果值：
#   key   未使用
#   value 未使用
# ============================================================

var wave_enemy_x = null # 被替换的敌人（预报）
var wave_enemy_y = null # 替换成的敌人（预报）

var wave_enemy_x_id = "" # 被替换敌人 id
var wave_enemy_y_id = "" # 替换成敌人 id


var effect_fengliu_can_swap_looter_enemies = Keys.generate_hash("fengliu_can_swap_looter_enemies")


# 随机预报下一波敌人替换
func fengliu_roll_next_wave_enemy_swap(player_index: int) -> void:
	# 获取下一波波次数据
	var wave_data = ZoneService.get_wave_data(RunData.current_zone, RunData.current_wave + 1)
	if wave_data == null:
		return

	var enemies := {}
	var enemy_ids := {} 

	# 遍历下一波的敌群
	for group in wave_data.groups_data:
		for unit in group.wave_units_data:
			# 非敌人单位则跳过
			if unit.type != EntityType.ENEMY or unit.unit_scene == null:
				continue
			# 收集下一波可能出现的敌人
			enemies[unit.unit_scene.resource_path] = unit.unit_scene.resource_path

			# 记录敌人 id
			var inst = unit.unit_scene.instance()
			if inst != null:
				var enemy_id = inst.get("enemy_id")
				enemy_ids[unit.unit_scene.resource_path] = enemy_id if enemy_id != null else ""
				inst.free()
			else:
				enemy_ids[unit.unit_scene.resource_path] = ""

	var paths = enemies.keys()
	# 敌人种类不足两个则不替换
	if paths.size() < 2:
		return

	# 随机取被替换的敌人
	wave_enemy_x = Utils.get_rand_element(paths)
	wave_enemy_x_id = enemy_ids[wave_enemy_x]

	var effects = RunData.get_player_effect(effect_fengliu_can_swap_looter_enemies, player_index)
	if effects.size() > 0 and Utils.get_chance_success(effects[0] / 100.0):
		var dlc = ProgressData.get_dlc_data("abyssal_terrors")
		if dlc != null and dlc.zones.has(ZoneService.get_zone_data(RunData.current_zone)):
			wave_enemy_y = 'res://dlcs/dlc_1/enemies/looting_pig/looting_pig.tscn'
			wave_enemy_y_id = 'looting_pig'
		else:
			wave_enemy_y = 'res://entities/units/enemies/looter/looter.tscn'
			wave_enemy_y_id = 'looter'
	else:
		# 随机取替换成的敌人（保证两者不同）
		wave_enemy_y = Utils.get_rand_element(paths)
		while wave_enemy_y == wave_enemy_x and paths.size() > 1:
			wave_enemy_y = Utils.get_rand_element(paths)

		wave_enemy_y_id = enemy_ids[wave_enemy_y]


func apply(player_index: int) -> void:
	# 把预报效果挂到玩家身上，下一波开始时由 WaveManager 统一收集并应用替换
	RunData.get_player_effect(custom_key_hash ,player_index).push_back(self)
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase(self)


func get_args(_player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0} {1} 占位符：
	#   [0] = 被替换的敌人名（绿色）
	#   [1] = 替换成的敌人名（绿色）
	return [
		"[color=lime]%s[/color]" % tr(wave_enemy_x_id.to_upper() + "_NAME" if wave_enemy_x_id != "" else "?"), 
		"[color=lime]%s[/color]" % tr(wave_enemy_y_id.to_upper() + "_NAME" if wave_enemy_y_id != "" else "?")
	]
