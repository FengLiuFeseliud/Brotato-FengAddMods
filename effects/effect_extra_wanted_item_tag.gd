class_name ExtraWantedItemTag
extends  "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"

# ============================================================
# 效果：额外「所需标签」
#   本吊牌 roll 出的标签写入玩家效果槽，商店刷新命中「所需标签」
#   概率时只保留带这些标签的道具。
#   运行时 custom_key：fengliu_extra_wanted_item_tag
# ============================================================


const ALL_ITEM_TAG = [
	# ---------------- 数值属性类（18）----------------
	"stat_max_hp",           # 30（26 / 2 / 2）
	"stat_elemental_damage", # 27（24 / 0 / 3）
	"stat_engineering",      # 26（25 / 1 / 0）
	"stat_percent_damage",   # 26（20 / 6 / 0）
	"stat_hp_regeneration",  # 25（21 / 4 / 0）
	"stat_melee_damage",     # 22（19 / 3 / 0）
	"stat_ranged_damage",    # 21（18 / 3 / 0）
	"stat_luck",             # 18（16 / 2 / 0）
	"stat_crit_chance",      # 16（15 / 1 / 0）
	"stat_lifesteal",        # 14（14 / 0 / 0）
	"stat_dodge",            # 13（12 / 1 / 0）
	"stat_range",            # 13（10 / 3 / 0）
	"stat_speed",            # 13（11 / 2 / 0）
	"stat_attack_speed",     # 12（9 / 3 / 0）
	"stat_armor",            # 11（11 / 0 / 0）
	"stat_harvesting",       # 11（10 / 1 / 0）
	"stat_fengliu_shield",   # 11（0 / 0 / 11）本 mod 专属
	"stat_curse",            # 5（0 / 5 / 0）DLC1 专属

	# ---------------- 玩法机制类（15）----------------
	"pet",                # 14（11 / 0 / 3）
	"structure",          # 13（13 / 0 / 0）
	"pickup",             # 11（9 / 1 / 1）
	"explosive",          # 10（8 / 2 / 0）
	"knockback",          # 10（9 / 1 / 0）
	"economy",            # 8（7 / 0 / 1）
	"xp_gain",            # 8（6 / 1 / 1）
	"exploration",        # 7（4 / 0 / 3）
	"consumable",         # 6（4 / 1 / 1）
	"stand_still",        # 4（3 / 1 / 0）
	"more_enemies",       # 3（2 / 1 / 0）
	"less_enemy_speed",   # 3（3 / 0 / 0）
	"less_enemies",       # 2（2 / 0 / 0）
	"number_of_enemies",  # 1（1 / 0 / 0）
	"lock",               # 1（0 / 1 / 0）DLC1 专属，无代码读取
]


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

	if taken.size() >= ALL_ITEM_TAG.size():
		roll_tags = Utils.get_rand_element(ALL_ITEM_TAG)
		return

	while true:
		roll_tags = Utils.get_rand_element(ALL_ITEM_TAG)
		if not taken.has(roll_tags):
			break


func apply(player_index: int) -> void:
    if roll_tags == "":
        fengliu_roll_effect(player_index)
        if roll_tags == "":
            return
    
    RunData.get_player_effect(custom_key_hash ,player_index).push_back(roll_tags)


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
