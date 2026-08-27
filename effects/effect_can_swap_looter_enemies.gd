class_name CanSwapLooterEnemies
extends Effect


# ============================================================
# 效果：预报替换为战利品外星人
#   天气预报的敌人替换有概率变为「战利品外星人」。
#   运行时 custom_key：fengliu_can_swap_looter_enemies
# ------------------------------------------------------------
# 效果值：
#   value  替换为战利品外星人的概率（%）
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back(value)
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase(value)


func get_args(_player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0} 占位符：
    #   [0] = 替换为战利品外星人的概率百分比（绿色）
    return [ "[color=lime]%s%%[/color]" % str(value) ]