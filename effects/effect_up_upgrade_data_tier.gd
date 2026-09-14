class_name UpUpgradeDataTier
extends Effect


# ============================================================
# 效果：升级项品阶提升
#   下一波升级时，升级属性项有概率提升「value」个品阶。
#   触发概率可吃倍率属性。
#   运行时 custom_key：fengliu_up_upgrade_data_tier
# ------------------------------------------------------------
# 效果值：
#   value       提升的品阶数量（如 1 = +1 品阶）
#   chance      基础触发概率（%）
#   key         倍率属性（提升概率所吃的属性，可为空）
#   gain_value  概率倍率（按 key 属性额外提升概率）
# ============================================================

export (int) var chance # 基础触发概率（%）
export (int) var gain_value = 0 # 概率倍率：按 key 属性额外提升概率


static func get_dynamic_chance(init_chance: int, add_chance: int = 100, stat_count: int = 0) -> int:
	var dynamic_chance = init_chance + (stat_count * (add_chance / 100.0))
	if dynamic_chance > 100:
		return 100
		
	return dynamic_chance


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, chance, gain_value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, chance, gain_value])


# 返回数组按顺序填充描述文本 {0}~{2} 占位符：
#   [0] = 动态触发概率百分比（绿色）
#   [1] = 提升的品阶数量（绿色 +N）
#   [2] = 倍率属性图标文本（无倍率属性时省略）
func get_args(player_index: int) -> Array:
    # 无倍率属性：直接返回固定概率与品阶数
    if key_hash == Keys.empty_hash:
        return [ "[color=lime]%s%%[/color]" % int(gain_value / 100.0), "[color=lime]+%s[/color]" % value ]

    # 有倍率属性：读取倍率属性值（等级取玩家等级）
    var stat_value = 0
    if key_hash != Keys.stat_levels_hash:
        stat_value = Utils.get_stat(key_hash, player_index)
    else:
        stat_value = RunData.get_player_level(player_index)
        
    # 返回动态概率、提升品阶数与倍率图标
    return [
        "[color=lime]%s%%[/color]" % get_dynamic_chance(value, gain_value, stat_value),
        "[color=lime]+%s[/color]" % value,
        Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)
    ]
