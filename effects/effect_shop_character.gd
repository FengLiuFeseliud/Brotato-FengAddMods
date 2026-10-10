class_name ShopCharacter
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：商店角色延迟应用（开关）
#   持有本效果时，商店买到的「角色」不立即应用，改为波次开始时最先应用；
#   角色效果与原角色效果同时存在；受到伤害后由队列里的下一个角色顶替。
#   未持有时，商店买到的角色直接应用（见 extensions/ui/menus/shop/base_shop.gd）。
#   运行时 custom_key：fengliu_shop_character
# ------------------------------------------------------------
# 效果值：
#   key    未使用
#   value  未使用
# ============================================================


static func get_id() -> String:
	return "fengliu_shop_character"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back([key_hash, value])


func unapply(player_index: int) -> void:
	var effects = RunData.get_player_effects(player_index)
	# 键缺失时直接跳过，避免旧档越界
	if not effects.has(custom_key_hash):
		return

	effects[custom_key_hash].erase([key_hash, value])
	# 失去效果时清场：摘掉生效角色并把 current_character 指回原角色
	RunData.fengliu_shop_character_clear(player_index)


func get_args(_player_index: int) -> Array:
	return [str(value)]
