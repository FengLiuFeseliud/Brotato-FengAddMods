class_name StrongerAliensOnStats
extends Effect


export (int) var gain_value = 0
export (String) var enemy_id = ""
var enemy_id_hash = 0


func _generate_hashes() -> void:
    ._generate_hashes()
    enemy_id_hash = Keys.generate_hash(enemy_id)


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, gain_value, enemy_id_hash])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, gain_value, enemy_id_hash])


func get_args(player_index: int) -> Array:
    var add_hp = value + int(Utils.get_stat(key_hash, player_index) * (gain_value / 100.0))
    return [
        tr(("%s_NAME" % enemy_id).to_upper()),
		"[color=lime]%s%%[/color]" % add_hp,
		Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)
	]