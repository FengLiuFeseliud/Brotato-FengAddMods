class_name ItemBoughtSpawnBoss
extends Effect


# ============================================================
# 效果：购买道具生成精英
#   购买指定道具时，按概率在下一波生成精英怪。
#   运行时 custom_key：fengliu_item_bought_spawn_boss
# ------------------------------------------------------------
# 效果值：
#   key              触发道具 ID（购买它才触发）
#   value            基础触发概率（%）
#   bought_add_chance 额外概率倍率（按已持有该道具数量 × bought_add_chance/100 累加）
# ============================================================

export (int) var bought_add_chance = 0 # 额外概率倍率（%）：按已持有数量累加


func get_item_count(player_index: int) -> int:
	var count = 0
	for item in RunData.get_player_items(player_index):
		if item.my_id_hash == key_hash:
			count += 1
	return count


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, bought_add_chance])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, bought_add_chance])


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{2} 占位符：
    #   [0] = 触发道具名（基类 args[1]）
    #   [1] = 当前触发概率百分比（绿色）
    #   [2] = 额外概率倍率百分比（绿色）
    var args = .get_args(player_index)

    var chance = 0
    if bought_add_chance != 0:
        chance = value + get_item_count(player_index) * (bought_add_chance / 100.0)
    return [
		args[1],
		"[color=lime]%s%%[/color]" % chance,
        "[color=lime]%s%%[/color]" % bought_add_chance
	]