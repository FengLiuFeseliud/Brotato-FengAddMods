class_name ItemMerge
extends Effect


# ============================================================
# 效果：道具合成
#   波次结束时，用若干道具合成另一道具（或武器）。
#   运行时 custom_key：fengliu_item_merge
# ------------------------------------------------------------
# 效果值：
#   key                  被消耗的源道具（同 merge_from_item）
#   value                （参与存储）
#   merge_from_item      消耗的源道具
#   merge_from_count     需要消耗的源道具数量
#   merge_to_item        合成目标道具/武器
#   merge_to_item_count  合成的目标数量
# ============================================================

export (int) var merge_from_count = 0 # 需要消耗的源道具数量
export (String) var merge_from_item # 消耗的源道具
export (String) var merge_to_item # 合成目标道具/武器
export (int) var merge_to_item_count = 1 # 合成的目标数量
var merge_from_item_hash = Keys.empty_hash
var merge_to_item_hash = Keys.empty_hash


func _generate_hashes() -> void:
    ._generate_hashes()
    merge_from_item_hash = Keys.generate_hash(merge_from_item)
    merge_to_item_hash = Keys.generate_hash(merge_to_item)


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, merge_from_item_hash, merge_from_count, merge_to_item_hash, merge_to_item_count])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, merge_from_item_hash, merge_from_count, merge_to_item_hash, merge_to_item_count])


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{2} 占位符：
    #   [0] = 基类 args[0]（key/value）
    #   [1] = 源道具名（大写翻译）
    #   [2] = 需要消耗的源道具数量
    var args = .get_args(player_index)
    return [
        args[0],
        tr(merge_from_item.to_upper()),
        str(merge_from_count)
    ]