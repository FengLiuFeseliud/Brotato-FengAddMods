class_name CanAllDropBoxEffect
extends Effect

# ============================================================
# 效果：果子改箱子（可随机出红箱）
#   把普通掉落果子改成箱子，并有概率出红箱（传奇）。
#   运行时 custom_key：fengliu_can_all_drop_box
# ------------------------------------------------------------
# 效果值：
#   key     倍率属性（概率倍率所吃的属性）
#   value   概率倍率（每 value/100 点该属性 +1% 概率）
#   chance  出红箱的基础概率（%）
# ============================================================

# 全部果子改为箱子 可随机触抽红箱子 概率可吃倍率属性
# key_hash 修改倍率属性
export (int) var chance = 0 # 出红箱的基础概率（%）
var stat_hash: int = Keys.empty_hash


func apply(player_index: int) -> void:
	FengLiuUtils.bind_effect(custom_key_hash, player_index, [key_hash, value, chance])
	
	
func unapply(player_index: int) -> void:
	FengLiuUtils.unbind_effect(custom_key_hash, player_index, [key_hash, value, chance])


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0} {1} 占位符：
	#   [0] = 动态出红箱概率百分比（绿色）
	#   [1] = 倍率属性图标文本
	var stat = Utils.get_stat(key_hash, player_index)
	return [
		FengLiuUtils.text_percent(FengLiuUtils.get_dynamic_chance(chance, value, stat)), 
		Utils.get_scaling_stat_icon_text(key_hash, value / 100.0), 
	]

