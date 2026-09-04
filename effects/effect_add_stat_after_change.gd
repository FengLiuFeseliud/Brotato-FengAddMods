class_name AddStatAfterChange
extends Effect

# ============================================================
# 效果：损失转换属性
#   当玩家损失「change_stat」属性时，按比例转换成另一属性。
#   若 key 以 "gain_" 开头，则为纯增益（损失时不扣除，只加）。
#   运行时 custom_key：fengliu_add_stat_after_change
#   （另有 fengliu_add_stat_cap 用于波次上限的显示版本）
# ------------------------------------------------------------
# 效果值：
#   key             获得的属性（以 "gain_" 开头 = 纯增益）
#   value           每次转换触发时增加的量
#   change_stat     被损失/被监控的属性
#   stat_scaled     每损失多少点 change_stat 触发一次转换
#   wave_max_value  波次转换上限（每波最多转换多少点）
# ============================================================

# 损失转换属性

export (String) var change_stat # 被损失属性
export (int) var stat_scaled # 转换触发所需损失
export (int) var wave_max_value # 波次上限
var change_stat_hash = ""
var gain_stat = false
var stat = ""


func _generate_hashes() -> void:
	._generate_hashes()
	# 目标属性：key 以 "gain_" 开头时去掉前缀；否则 key 本身就是目标属性
	stat = key.substr("gain_".length()) if key.begins_with("gain_") else key
	change_stat_hash = Keys.generate_hash(change_stat)


func apply(player_index: int) -> void:
	if "gain_" in key:
		gain_stat = true
	RunData.get_player_effect(custom_key_hash, player_index).push_back([key_hash, value, change_stat_hash, stat_scaled, wave_max_value, gain_stat])
	
	
func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, change_stat_hash, stat_scaled, wave_max_value, gain_stat])
	
	
func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{5} 占位符：
	#   [0] = 被损失属性名 (change_stat)
	#   [1] = 转换所需损失 (stat_scaled)
	#   [2] = 获得属性名 / 被损失属性名（视分支）
	#   [3] = 基础数值 / 获得属性名（视分支）
	#   [4] = 波次上限 (wave_max_value)
	#   [5] = 实际转换获得量（绿色 +N 或 +N%）
	var args = .get_args(player_index)
	
	var add_stat = 0
	if custom_key == "fengliu_add_stat_cap":
		var change_stat_count = 0
		var change_stat_effect = RunData.get_player_effect(change_stat_hash, player_index)
		if change_stat_effect.size() > 0:
			change_stat_count = change_stat_effect[0]
			
		if change_stat == "levels":
			change_stat_count = RunData.get_player_level(player_index)
			
		add_stat = value * int(change_stat_count / stat_scaled)
		return [
			tr(change_stat.to_upper()), 
			str(stat_scaled), 
			args[1], 
			args[0], 
			str(wave_max_value), 
			"[color=lime]+%s[/color]" % add_stat
		]
	
	if gain_stat or not "stat" in key:
		add_stat = RunData.get_player_effect(key_hash, player_index)
		var stat_display = stat if stat != "" else key
		return [
			tr(change_stat.to_upper()), 
			str(stat_scaled), 
			tr(stat_display.to_upper()), 
			args[0], 
			str(wave_max_value), 
			"[color=lime]+%s%%[/color]" % add_stat
		]
	
	var remove_stat = 0
	var effects = RunData.get_player_effect(Keys.generate_hash("remove_%s" % change_stat), player_index)
	if effects.size() > 0:
		remove_stat = effects[0]
		
	add_stat = value * int(remove_stat / stat_scaled)
	return [
		tr(change_stat.to_upper()), 
		str(stat_scaled), 
		args[1], 
		args[0], 
		str(wave_max_value), 
		"[color=lime]+%s[/color]" % add_stat
	]
