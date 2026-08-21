class_name WaveIntensityDamage
extends Effect


# ============================================================
# 效果：波次强度附加伤害
#   攻击时附加「波次每秒总血量」百分比的伤害。
#   适用于「适应者」角色，波次强度越高附加伤害越高。
#   运行时 custom_key：fengliu_wave_intensity_damage
# ------------------------------------------------------------
# 效果值：
#   value  附加伤害百分比（%）= 波次每秒总血量 × value%
# ============================================================

# 波次强度附加伤害

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([value])


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0} 占位符：
    #   [0] = 附加伤害百分比（绿色）
    return ["[color=lime]%s%%[/color]" % .get_args(player_index)[0]]