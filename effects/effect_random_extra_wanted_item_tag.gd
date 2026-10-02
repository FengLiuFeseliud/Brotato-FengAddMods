class_name RandomExtraWantedItemTag
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"

# ============================================================
# 效果：每波随机所需标签
#   每波敌袭结束时把 value 组随机标签写进玩家的「所需标签」槽，
#   下一波敌袭开始时再把这些随机标签移除。
#   运行时 custom_key：fengliu_random_extra_wanted_item_tag
# ------------------------------------------------------------
# 效果值：
#   value    每波追加的随机标签数量
# ============================================================


var effect_fengliu_extra_wanted_item_tag = Keys.generate_hash("fengliu_extra_wanted_item_tag")


static func get_id() -> String:
	return "fengliu_random_extra_wanted_item_tag"


# 登记本效果：槽位里每个条目代表每波追加的 1 组随机标签
func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back(value)
	

# 移除登记：只抹掉一个同值条目
func unapply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).erase(value)


func get_args(player_index: int) -> Array:
	var args = .get_args(player_index)
	# 汇总当前生效的「所需标签」：吊牌道具 roll 出的 + 角色自带的
	var wanted_tags: Array = RunData.get_player_effect(effect_fengliu_extra_wanted_item_tag, player_index).duplicate()
	var player_character = RunData.get_player_character(player_index)
	if player_character != null:
		wanted_tags.append_array(player_character.wanted_tags)

	# 去重后拼成展示文本
	var wanted_tags_name := []
	var seen := {}
	for wanted_tag in wanted_tags:
		var tag_text := tr(str(wanted_tag).to_upper())
		if seen.has(tag_text):
			continue

		seen[tag_text] = true
		wanted_tags_name.append(tag_text)

	return [args[0], "[color=lime]%s[/color]" % "/".join(wanted_tags_name)]