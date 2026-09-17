class_name CanRandSetWeapon
extends Effect


# ============================================================
# 效果：限定可获得的武器类别
#   商店刷出的武器会被替换为「家居」套装武器，玩家实际只能拿到该类武器。
#   运行时 custom_key：fengliu_can_rand_set_weapon
# ------------------------------------------------------------
# 效果值：
#   key     武器类别（set_homeware → WEAPON_CLASS_HOMEWARE 家居）
#   value   （不参与逻辑，仅作存在标记）
# ============================================================


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash])


func get_args(_player_index: int) -> Array:
	# 由 key 推导武器类别翻译 key（set_homeware → weapon_class_homeware）
	return [ tr(key.to_upper().replace("SET", "WEAPON_CLASS")) ]