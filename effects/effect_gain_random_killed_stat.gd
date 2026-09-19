class_name GainRandomStatEveryKilledEnemiesEffect
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_null_effect.gd"

# ============================================================
# 效果：杀敌随机获得属性
#   每击杀 value 个敌人，随机获得一次主属性。
#   运行时 custom_key：fengliu_gain_random_killed_stat
# ------------------------------------------------------------
# 效果值：
#   value          每击杀多少敌人触发一次
#   stat           随机增加的属性
#   stat_min_value 随机下限
#   stat_max_value 随机上限
#   stat_no_zero   随机值不能为 0
# ============================================================

# 杀敌随机触发效果

export (String) var stat = "" # 触发增加属性
export (int) var stat_min_value # 随机下限
export (int) var stat_max_value # 随机上限
export (bool) var stat_no_zero = false # 随机没有 0
var stat_hash: int = Keys.empty_hash


static func get_id() -> String:
	return "fengliu_gain_random_killed_stat"


func _generate_hashes() -> void :
	# 预生成随机属性哈希
	._generate_hashes()
	stat_hash = Keys.generate_hash(stat)
	
	
func get_dynamic_value() -> int:
	# 在 [下限, 上限] 内取随机整数
	var dynamic_value = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	if dynamic_value == 0 and stat_no_zero:
		# 不允许 0 时重新抽取
		return get_dynamic_value()
	return dynamic_value


func get_args(_player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{4} 占位符：
	#   [0] = 本次随机值（展示用）
	#   [1] = 属性名（大写翻译）
	#   [2] = 每击杀多少敌人触发 (value)
	#   [3] = 随机下限 (stat_min_value)
	#   [4] = 随机上限 (stat_max_value)
	var random_val = int(floor(rand_range(stat_min_value, stat_max_value + 1)))
	return [
		str(random_val), 
		tr(stat.to_upper()), 
		str(value), 
		str(stat_min_value), 
		str(stat_max_value)
	]
