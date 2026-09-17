extends ItemExplodingEffect


export (float) var wait_time = 0.0
export (bool) var exploding_on_clean_up_room = false


func apply(player_index: int) -> void:
	RunData.get_player_effect(key_hash ,player_index).push_back(self)
	
	
func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[key_hash].erase(self)


func get_args(player_index: int) -> Array:
    var args = .get_args(player_index)
    # 追加等待时间，供描述文本的 {1} 显示
    args.append(str(wait_time))
    return args


func serialize() -> Dictionary:
    # 额外序列化「等待时间」与「清场爆炸」开关
    var serialized = .serialize()
    serialized.wait_time = wait_time
    serialized.exploding_on_clean_up_room = exploding_on_clean_up_room
    return serialized


func deserialize_and_merge(serialized: Dictionary) -> void :
    # 还原新增字段，旧存档缺失时使用默认值
    .deserialize_and_merge(serialized)
    wait_time = serialized.get("wait_time", 0.0)
    exploding_on_clean_up_room = serialized.get("exploding_on_clean_up_room", false)