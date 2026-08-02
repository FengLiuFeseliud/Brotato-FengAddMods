class_name CanAddChanceStatDemageEffect
extends ChanceStatDamageEffect

# 概率触发效果 可提升概率吃倍率属性

export (String) var add_chance_stat = "" # 概率倍率属性
export (int) var add_chance = 0 # 概率倍率
export (bool) var stat_no_zero = false # 随机没有 0
var add_chance_stat_hash = ""


func _generate_hashes() -> void:
	._generate_hashes()
	add_chance_stat_hash = Keys.generate_hash(add_chance_stat)


static func get_id() -> String:
	return "effect_can_add_chance_stat_damage"
	

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, chance, tracking_key, add_chance_stat_hash, add_chance, chance])
	
	
func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, chance, tracking_key, add_chance_stat_hash, add_chance, chance])
	
	
static func get_dynamic_chance(stat_count: int, init_chance: int, _add_chance: int) -> int:
	var dynamic_chance = int(init_chance + (stat_count * (_add_chance / 100.0)))
	if dynamic_chance > 100:
		return 100
		
	return dynamic_chance


func get_args(player_index: int) -> Array:
	var args = .get_args(player_index)
	var scaling_add_chance_text = Utils.get_scaling_stat_icon_text(Keys.generate_hash(add_chance_stat), add_chance / 100.0, false)
	var stat = Utils.get_stat(add_chance_stat_hash, player_index)
	return [
		"[color=lime]%s%%[/color]" % get_dynamic_chance(stat, chance, add_chance), 
		scaling_add_chance_text, 
		args[1], 
		args[2]
	]
