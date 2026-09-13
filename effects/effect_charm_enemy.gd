class_name CharmEnemy
extends Effect


# ============================================================
# 效果：魅惑敌人
#   被指定类型攻击命中的敌人有概率被魅惑；敌人生命值为 1 时必定魅惑，
#   精英/Boss 生命值低于阈值时也会被魅惑。
#   运行时 custom_key：fengliu_charm_enemy
# ------------------------------------------------------------
# 效果值：
#   key              触发魅惑的攻击类型（如 Structure = 构造物）
#   value            基础魅惑概率（%）
#   boss_charm       是否允许魅惑 Boss/精英
#   boss_charm_value Boss/精英魅惑生命值阈值（%）
# ============================================================

export (bool) var boss_charm = false # 是否允许魅惑 Boss/精英
export (int) var boss_charm_value = 0 # Boss/精英魅惑生命值阈值（%）


func apply(player_index: int) -> void:
	FengLiuUtils.bind_effect(custom_key_hash, player_index, [key, value, boss_charm, boss_charm_value])
	

func unapply(player_index: int) -> void:
	FengLiuUtils.unbind_effect(custom_key_hash, player_index, [key, value, boss_charm, boss_charm_value])


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{2} 占位符：
	#   [0] = 基础魅惑概率百分比（绿色）
	#   [1] = 触发魅惑的攻击类型名（基类 args[1]）
	#   [2] = Boss/精英魅惑生命值阈值百分比（绿色）
	var args = .get_args(player_index)
	return [
        FengLiuUtils.text_percent(args[0]),
		FengLiuUtils.text_value(args[1]),
		FengLiuUtils.text_percent(boss_charm_value)
	]