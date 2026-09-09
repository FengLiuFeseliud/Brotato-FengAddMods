class_name TemporaryStatsStop
extends NullEffect


# ============================================================
# 效果：属性代偿（临时用属性购买）
#   使后续 value 次购买可用最高主属性代替材料（次数可叠加）。
#   运行时 custom_key：fengliu_temporary_stats_stop
# ------------------------------------------------------------
# 效果值：
#   value  新增的代偿购买次数（可叠加）
# ============================================================

func apply(player_index: int) -> void:
    var effect = RunData.get_player_effect(custom_key_hash ,player_index)
    if not effect is int:
        effect = 0

    effect += value
    RunData.get_player_effects(player_index)[custom_key_hash] = effect


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{1} 占位符：
    #   [0] = 本次新增的代偿次数
    #   [1] = 当前累计代偿次数
    var count = RunData.get_player_effect(custom_key_hash ,player_index)
    if not count is int:
        count = 0

    return [
        "[color=lime]%s[/color]" % value,
        "[color=lime]+%s[/color]" % count
    ]