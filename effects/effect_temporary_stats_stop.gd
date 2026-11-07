class_name TemporaryStatsStop
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_null_effect.gd"


# ============================================================
# 效果：属性代偿（临时用属性购买）
#   使后续 value 次购买可用最高主属性代替材料（次数可叠加）。
#   运行时 custom_key：fengliu_temporary_stats_stop
# ------------------------------------------------------------
# 效果值：
#   value  新增的代偿购买次数（可叠加）
# ============================================================


static func get_id() -> String:
	return "fengliu_temporary_stats_stop"


# 数值累加 / 消费端遍历，异变复制有效
func fengliu_can_be_copied_by_mutation() -> bool:
	return true


func fengliu_get_effect_init_value():
	return 0


func apply(player_index: int) -> void:
    var count = RunData.get_player_effect(custom_key_hash, player_index)
    count += value
    # 写回累计后的次数，供商店代偿购买读取
    RunData.get_player_effects(player_index)[custom_key_hash] = count


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{1} 占位符：
    #   [0] = 本次新增的代偿次数
    #   [1] = 当前累计代偿次数
    var count = RunData.get_player_effect(custom_key_hash, player_index)

    return [
        "[color=lime]%s[/color]" % value,
        str(count)
    ]