class_name CanRandSetWeapon
extends Effect


# ============================================================
# 效果：限定可获得的武器类别
#   商店刷出的武器会被替换为 key 套装武器，玩家实际只能拿到该类武器。
#   运行时 custom_key：fengliu_can_rand_set_weapon
# ------------------------------------------------------------
# 效果值：
#   key     武器类别
#   value   （不参与逻辑，仅作存在标记）
# ============================================================

var roll_set: SetData


func fengliu_roll_effect(player_index: int) -> void:
	roll_set = RunData.fengliu_get_player_random_weapon_set(player_index)


func apply(player_index: int) -> void:
	if key_hash == Keys.empty_hash:
		if roll_set == null:
			return
			
		key = roll_set.my_id
		key_hash = roll_set.my_id_hash

	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash])


func get_args(_player_index: int) -> Array:
	var key_text = tr(key.to_upper().replace("SET", "WEAPON_CLASS"))
	if key_hash == Keys.empty_hash:
		if roll_set == null:
			return [ "[color=lime]?[/color]" ]

		key_text = tr(roll_set.name)
		
	return [ "[color=lime]%s[/color]" % key_text ]