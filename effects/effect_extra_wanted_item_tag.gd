class_name ExtraWantedItemTag
extends  "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"

# ============================================================
# 效果：额外「所需标签」
#   本吊牌 roll 出的标签写入玩家效果槽，商店刷新命中「所需标签」
#   概率时只保留带这些标签的道具。
#   运行时 custom_key：fengliu_extra_wanted_item_tag
# ============================================================


var roll_tags: String = ""


static func get_id() -> String:
	return "fengliu_extra_wanted_item_tag"


func fengliu_persist_var_names() -> Array:
	return ["roll_tags"]


func fengliu_roll_effect(player_index: int):
	var taken := {}
	var player_character = RunData.get_player_character(player_index)
	if player_character != null:
		for tag in player_character.wanted_tags:
			taken[str(tag)] = true

	for tag in RunData.get_player_effect(custom_key_hash, player_index):
		taken[str(tag)] = true

	if taken.size() >= RunData.all_item_tags.size():
		roll_tags = Utils.get_rand_element(RunData.all_item_tags)
		return

	while true:
		roll_tags = Utils.get_rand_element(RunData.all_item_tags)
		if not taken.has(roll_tags):
			break


func apply(player_index: int) -> void:
    if roll_tags == "":
        fengliu_roll_effect(player_index)
        if roll_tags == "":
            return
    
    RunData.get_player_effect(custom_key_hash ,player_index).push_front(roll_tags)


func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase(roll_tags)


func get_args(player_index: int) -> Array:
    var wanted_tags: Array = RunData.get_player_effect(custom_key_hash, player_index).duplicate()
    var player_character = RunData.get_player_character(player_index)
    if player_character != null:
        wanted_tags.append_array(player_character.wanted_tags)

    var wanted_tags_name := []
    var seen := {}
    for wanted_tag in wanted_tags:
        var tag_text := tr(str(wanted_tag).to_upper())
        if seen.has(tag_text):
            continue

        seen[tag_text] = true
        wanted_tags_name.append(tag_text)

    if roll_tags == "":
        return ["[color=lime]?[/color]", "[color=lime]%s[/color]" % "/".join(wanted_tags_name)]

    return ["[color=lime]%s[/color]" % tr(str(roll_tags).to_upper()), "[color=lime]%s[/color]" % "/".join(wanted_tags_name)]
