extends Consumable


var effect_fengliu_wave_end_not_pick_consumable: int = Keys.generate_hash("fengliu_wave_end_not_pick_consumable")


# 任一玩家持有「波次结束不拾取」效果即可
func fengliu_has_wave_end_not_pick_effect() -> bool:
	for player_index in RunData.get_player_count():
		if RunData.get_player_effect(effect_fengliu_wave_end_not_pick_consumable, player_index).size() > 0:
			return true
	return false


func should_be_picked_up_at_end_of_wave() -> bool:
	if fengliu_has_wave_end_not_pick_effect():
		return false
	return .should_be_picked_up_at_end_of_wave()
