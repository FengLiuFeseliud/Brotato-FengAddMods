class_name PickBoxCostGold
extends Effect


# ============================================================
# 效果：付费开箱
#   拾取箱子需要花费金币，且花费随波次通胀；
#   若无法升级武器则补偿随机主属性。
#   运行时 custom_key：fengliu_picke_box_cost_gold
# ------------------------------------------------------------
# 效果值：
#   value               开箱基础花费金币
#   wave_inflation_rate 每波通胀率（花费 = value × (1 + (波次-1) × 通胀率)）
#   random_get_stat     无法升级武器时，补偿随机主属性的次数
# ============================================================

export (float) var wave_inflation_rate # 每波通胀率
export (int) var random_get_stat = 0 # 随机获取属性（无法升级武器时的补偿次数）


func get_box_cost() -> int:
    return int(value * (1.0 + (max(1, RunData.current_wave) - 1) * wave_inflation_rate))


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, wave_inflation_rate, random_get_stat])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, wave_inflation_rate, random_get_stat])


func get_args(_player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0} {1} 占位符：
	#   [0] = 开箱当前花费金币
	#   [1] = 随机获取属性次数（绿色）
	return [
		str(get_box_cost()), 
		"[color=lime]%s[/color]" % str(random_get_stat)
	]
