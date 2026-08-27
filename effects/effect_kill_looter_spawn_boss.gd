class_name KillLooterSpawnBoss
extends Effect


# ============================================================
# 效果：击杀战利品外星人概率生成 Boss
#   击杀战利品外星人时，有概率在原地生成一个随机精英 Boss。
#   运行时 custom_key：fengliu_kill_looter_spawn_boss
# ------------------------------------------------------------
# 效果值：
#   value  生成 Boss 的概率（%）
# ============================================================

func apply(player_index: int) -> void:
    RunData.get_player_effect(custom_key_hash, player_index).push_back(value)


func unapply(player_index: int) -> void:
    RunData.get_player_effects(player_index)[custom_key_hash].erase(value)


func get_args(_player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0} 占位符：
    #   [0] = 生成 Boss 的概率百分比（绿色）
    return [ "[color=lime]%s%%[/color]" % str(value) ]