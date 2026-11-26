extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：剑气大小随射程提升
#   套装触发时把「射程除数」写入玩家效果槽，供
#   melee_projectile_attack 读取并缩放子弹根节点。
#   运行时 custom_key：fengliu_melee_projectile_scale_by_range
# ------------------------------------------------------------
# 效果值：
#   value   射程除数（倍率 = 面板射程 / value，默认 100）
# ============================================================

const SCALE_SLOT_KEY := "fengliu_melee_projectile_scale_by_range"


static func get_id() -> String:
	return "fengliu_melee_projectile_scale_by_range"


# 条件型/套装触发的行为效果，不参与异变复制
func fengliu_can_be_copied_by_mutation() -> bool:
	return false


func fengliu_get_effect_init_value():
	return 0


func apply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	effects[_scale_slot_hash()] = max(1, value)


func unapply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	effects[_scale_slot_hash()] = 0


func get_args(_player_index: int) -> Array:
	return [str(value)]


func get_icon(_player_index: int) -> Texture:
	return ItemService.get_stat_small_icon(Keys.stat_range_hash) as Texture


func _scale_slot_hash() -> int:
	# custom_key 已生成时优先用它，避免初始化时序问题
	if custom_key_hash != Keys.empty_hash:
		return custom_key_hash
		
	return Keys.generate_hash(SCALE_SLOT_KEY)
