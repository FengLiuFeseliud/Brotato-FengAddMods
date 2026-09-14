class_name RandomCurse
extends Effect


# ============================================================
# 效果：随机诅咒
#   满足条件时，消耗指定数量道具 + 等级，随机诅咒一件道具/武器。
#   运行时 custom_key：fengliu_random_curse
# ------------------------------------------------------------
# 效果值：
#   key                 被消耗（献祭）的道具 ID
#   value               需要持有的该道具数量
#   need_level          需要达到的等级
#   not_curse_item_ids  不可被诅咒的道具 ID 排除列表
# ============================================================

export (int) var need_level = 0 # 需要达到的等级
export (Array) var not_curse_item_ids = [] # 不可被诅咒的道具 ID 排除列表
var not_curse_item_ids_hash = []


func _generate_hashes() -> void:
    ._generate_hashes()
    for not_curse_item_id in not_curse_item_ids:
        not_curse_item_ids_hash.append(Keys.generate_hash(not_curse_item_id))


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, need_level, not_curse_item_ids_hash])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, need_level, not_curse_item_ids_hash])


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{2} 占位符：
    #   [0] = 需要持有的道具数量 (value)
    #   [1] = 被消耗道具名（基类 args[1]）
    #   [2] = 需要达到的等级 (need_level)
    var args = .get_args(player_index)
    return [
        args[0],
        args[1],
        str(need_level)
    ]