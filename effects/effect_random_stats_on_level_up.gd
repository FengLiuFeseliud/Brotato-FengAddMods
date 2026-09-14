class_name RandomStatsOnLavalUpEffect
extends Effect

# ============================================================
# 效果：升级随机加属性
#   升级时随机增加主属性，随机值可吃倍率属性。
#   运行时 custom_key：fengliu_random_stats_on_level_up
# ------------------------------------------------------------
# 效果值：
#   key             随机增加的属性
#   stat_min_value  随机下限
#   stat_max_value  随机上限
#   stat_no_zero    随机值不能为 0
#   stat_gain       倍率属性（提升随机范围所吃的属性）
#   stat_gain_value 倍率（随机值 × (1 + int(倍率属性/stat_gain_value))）
# ============================================================

# 升级随机增加属性 可吃倍率

export (int) var stat_min_value # 随机下限
export (int) var stat_max_value # 随机上限
export (bool) var stat_no_zero = false # 随机没有 0
export (String) var stat_gain = "" # 修改倍率属性
export (float) var stat_gain_value = 0.0 # 倍率
var random_stat: int = 0
var stat_gain_hash = ""


func _generate_hashes() -> void:
	._generate_hashes()
	if stat_gain_value == 0:
		return
	
	stat_gain_hash = Keys.generate_hash(stat_gain)


static func get_id() -> String:
	return "effect_random_stats_on_level_up"
	
	
func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, stat_min_value, stat_max_value, stat_no_zero, stat_gain_hash, stat_gain_value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, stat_min_value, stat_max_value, stat_no_zero, stat_gain_hash, stat_gain_value])


func get_args(player_index: int):
	# 返回数组按顺序填充描述文本 {0}~{5} 占位符：
	#   [0] = 随机下限 (stat_min_value)
	#   [1] = 随机上限 (stat_max_value)
	#   [2] = 属性名（基类 args[1]）
	#   [3] = 倍率属性名（无倍率时省略）
	#   [4] = 倍率值（无倍率时省略）
	#   [5] = 动态随机范围（绿色，无倍率时省略）
	var args = .get_args(player_index)
	
	if stat_gain_value == 0:
		return [str(stat_min_value), str(stat_max_value), args[1]]
		
	var stat_velue = RunData.get_stat(stat_gain_hash, player_index)
	var velue_text = str(stat_min_value * (1 + int(stat_velue / stat_gain_value))) + "~" + str(stat_max_value * (1 + int(stat_velue / stat_gain_value))) 
	return [
		str(stat_min_value), 
		str(stat_max_value), 
		args[1], 
		tr(stat_gain.to_upper()), 
		str(stat_gain_value), 
		"[color=lime]%s[/color]" % velue_text
	]
