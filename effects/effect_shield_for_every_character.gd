class_name StatForEveryCharacter
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：每持有一个角色增加属性
#   按背包里持有的角色数量，给「key」指定的属性加值；数量变化时同步增减。
#   运行时 custom_key：fengliu_stat_per_character
# ------------------------------------------------------------
# 效果值：
#   key    目标属性（例如 stat_fengliu_shield）
#   value  每持有一个角色增加的量
# ============================================================


static func get_id() -> String:
	return "fengliu_stat_per_character"


func apply(player_index: int) -> void:
	# 登记本次持有结算（第 3 项＝已结算的持有个数），再按当前持有数补上属性
	RunData.get_player_effect(custom_key_hash, player_index).push_back([fengliu_stat_hash(), value, 0])
	RunData.fengliu_stat_per_character_sync(player_index)


func unapply(player_index: int) -> void:
	var stat_hash = fengliu_stat_hash()
	var effect_list = RunData.get_player_effects(player_index).get(custom_key_hash, [])
	for effect in effect_list:
		if effect.size() < 2 or int(effect[0]) != stat_hash or int(effect[1]) != value:
			continue

		# 回滚已结算的部分
		var applied_count = int(effect[2]) if effect.size() > 2 else 0
		if applied_count != 0:
			RunData.add_stat(stat_hash, -value * applied_count, player_index)

		effect_list.erase(effect)
		return


func get_args(player_index: int) -> Array:
	# {0}=每角色加值 {1}=属性名 {2}=当前持有角色数
	var character_count = 0
	if player_index >= 0:
		character_count = RunData.fengliu_count_owned_characters(player_index)

	return [str(value), tr(key.to_upper()), str(character_count * value)]


# 目标属性哈希（尚未生成时按 key 现算）
func fengliu_stat_hash() -> int:
	# 已生成则直接用
	if key_hash != Keys.empty_hash:
		return key_hash

	return Keys.generate_hash(key)
