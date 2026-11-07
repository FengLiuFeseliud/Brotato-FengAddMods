class_name WaveIntensityDamage
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：波次强度附加伤害
#   攻击时附加「波次每秒总血量」百分比的伤害。
#   适用于「适应者」角色，波次强度越高附加伤害越高。
#   运行时 custom_key：fengliu_wave_intensity_damage
# ------------------------------------------------------------
# 效果值：
#   value  附加伤害百分比（%）= 波次每秒总血量 × value%
# ============================================================


static func get_id() -> String:
	return "fengliu_wave_intensity_damage"


# 数值累加 / 消费端遍历，异变复制有效
func fengliu_can_be_copied_by_mutation() -> bool:
	return true


# 波次强度附加伤害

func apply(player_index: int) -> void :
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = effects.get(custom_key_hash, 0) + value
	

func unapply(player_index: int) -> void :
	var effects = RunData.get_player_effects(player_index)
	effects[custom_key_hash] = max(0, effects.get(custom_key_hash, 0) - value)


# 槽位存的是单个数值（不是列表）
func fengliu_get_effect_init_value():
	return 0


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0} 占位符：
    #   [0] = 附加伤害百分比（绿色）
    return [str(.get_args(player_index)[0])]