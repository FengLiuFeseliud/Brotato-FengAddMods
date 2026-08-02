class_name GainRandomStatEveryKilledEnemiesEffect
extends NullEffect

# 杀敌随机触发效果

export (String) var stat = "" # 触发增加属性
export (int) var stat_min_value # 随机下限
export (int) var stat_max_value # 随机上限
export (bool) var stat_no_zero = false # 随机没有 0
var stat_hash: int = Keys.empty_hash


func _generate_hashes() -> void :
	._generate_hashes()
	stat_hash = Keys.generate_hash(stat)


static func get_id() -> String:
	return "effect_gain_random_killed_stat"
	
	
func get_dynamic_value() -> int:
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	if dynamic_value == 0 and stat_no_zero:
		return get_dynamic_value()
	return dynamic_value


func get_args(_player_index: int) -> Array:
	var random_val = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	return [
		str(random_val), 
		tr(stat.to_upper()), 
		str(value), 
		str(stat_min_value), 
		str(stat_max_value)
	]
