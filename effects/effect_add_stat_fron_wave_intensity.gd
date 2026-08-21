class_name AddStatFromWaveIntensity
extends Effect


# ============================================================
# 效果：波次强度增加属性
#   通过近期高质量波次时增加「key」属性；通过敌众或精英波次时
#   增加更多。适用于「适应者」角色，随波次强度成长武器槽等属性。
#   运行时 custom_key：fengliu_add_stat_fron_wave_intensity
# ------------------------------------------------------------
# 效果值：
#   key                  增加的属性（以 "stat_" 开头 = 直接加属性，否则加增益）
#   value                高质量波次时增加的量
#   boss_wave_add_value  敌众/精英波次时增加的量
#   value_cap            属性上限
# ============================================================

# 波次强度增加属性

export (int) var boss_wave_add_value = 0 # 敌众/精英波次增加量
export (int) var value_cap = 0 # 属性上限


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, boss_wave_add_value, value_cap, "stat_" in key])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, boss_wave_add_value, value_cap, "stat_" in key])


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{3} 占位符：
	#   [0] = 增加的属性名（基类 args[1]）
	#   [1] = 高质量波次增加量 (value)（基类 args[0]）
	#   [2] = 敌众/精英波次增加量 (boss_wave_add_value)
	#   [3] = 属性上限 (value_cap)
	var args = .get_args(player_index)
	return [
		args[1],
		args[0],
		str(boss_wave_add_value),
		str(value_cap)
	]