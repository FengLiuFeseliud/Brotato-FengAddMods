class_name WeaponHitSlowEffect
extends NullEffect


# ============================================================
# 效果：武器命中减速
#   用该武器命中敌人时，对敌人施加短暂减速。
#   减速值可吃倍率属性。
#   运行时 custom_key：fengliu_weapon_hit_slow
# ------------------------------------------------------------
# 效果值：
#   key        减速倍率属性（提升减速值所吃的属性）
#   value      基础减速值
#   gain_value 减速倍率（减速值 += 该属性 × gain_value/100）
# ============================================================

export (int) var gain_value = 0 # 减速倍率：减速值 += 该属性 × gain_value/100


func get_args(player_index: int) -> Array:
    # 计算当前减速值（基础值 + 属性倍率）
    var slow_value = value + int(Utils.get_stat(key_hash, player_index) * (gain_value / 100.0))
    return [
        "[color=lime]%s[/color]" % slow_value,
        Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)
    ]