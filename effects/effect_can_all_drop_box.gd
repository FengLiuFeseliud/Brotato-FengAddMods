class_name CanAllDropBoxEffect
extends Effect

# 全部果子改为箱子 可随机触抽红箱子 概率可吃倍率属性
# key_hash 修改倍率属性
export (int) var chance = 0
var stat_hash: int = Keys.empty_hash


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, chance])
	
	
func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, chance])


static func get_dynamic_chance(stat_count: int, init_chance: int, _add_chance: int) -> int:
	var dynamic_chance = int(init_chance + (stat_count * (_add_chance / 100.0)))
	if dynamic_chance > 100:
		return 100
		
	return dynamic_chance


func get_args(player_index: int) -> Array:
	var stat = Utils.get_stat(key_hash, player_index)
	return [
		"[color=lime]%s%%[/color]" % get_dynamic_chance(stat, chance, value), 
		Utils.get_scaling_stat_icon_text(key_hash, value / 100.0, false), 
	]

