class_name WeaponKilledLoot
extends NullEffect


# ============================================================
# 效果：武器击杀掉落箱子
#   用该武器每击杀一定数量敌人，掉落一个箱子。
#   运行时 custom_key：fengliu_weapon_killed_loot
# ------------------------------------------------------------
# 效果值：
#   key        若为 "wave_gain"，击杀数随波次成长；否则为倍率属性
#   value      基础击杀数（每击杀多少敌人掉一次箱子）
#   gain_value 成长倍率（击杀数 = value + 波次 × gain_value，或按属性缩放）
#   cap_value  击杀数上限
# ============================================================

# wave_count

export (float) var gain_value = 0.0 # 成长倍率
export (float) var cap_value = 0.0 # 击杀数上限


func get_args(_player_index: int) -> Array:

    # 返回数组按顺序填充描述文本 {0}~{2} 占位符：
    #   [0] = 当前击杀数要求 (value_count)
    #   [1] = 成长倍率 / 倍率属性图标文本
    #   [2] = 击杀数上限 (cap_value)
    var value_count = 0
    var text = ""

    if "wave_gain" == key:
        value_count = value + RunData.current_wave * gain_value
        if value_count > cap_value and cap_value > 0:
            value_count = cap_value
        text = "[color=lime]%s[/color]" % int(gain_value)
    else:
        text = Utils.get_scaling_stat_icon_text(key_hash, gain_value)

    return [
        str(value_count),
        text,
        str(cap_value)
    ]