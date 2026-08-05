class_name AddStatAfterChange
extends Effect

# 损失转换属性

export (String) var change_stat # 被损失属性
export (int) var stat_scaled # 转换触发所需损失
export (int) var wave_max_value # 波次上限
var change_stat_hash = ""
var gain_stat = false
var stat = ""
var stat_kay = ""


func _generate_hashes() -> void:
	._generate_hashes()
	if "gain_" in key:
		stat = key.lstrip("gain_")
		stat_kay = Keys.generate_hash(stat_kay)
	change_stat_hash = Keys.generate_hash(change_stat)


func apply(player_index: int) -> void:
	if "gain_" in key:
		gain_stat = true
	RunData.get_player_effect(custom_key_hash, player_index).push_back([key_hash, value, change_stat_hash, stat_scaled, wave_max_value, gain_stat])
	
	
func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, change_stat_hash, stat_scaled, wave_max_value, gain_stat])
	
	
func get_args(player_index: int) -> Array:
	var args = .get_args(player_index)
	
	var add_stat = 0
	if custom_key == "add_stat_cap":
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
		return [
			tr(change_stat.to_upper()), 
			str(stat_scaled), 
			tr(stat.to_upper()), 
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
