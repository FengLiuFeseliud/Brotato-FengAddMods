class_name GetFixedUpgradeData
extends Effect


# ============================================================
# 效果：固定下一波升级项
#   下一波升级时，升级属性项固定为随机抽取的若干项（定向训练）。
#   若同时拥有「必含最高属性」效果，则先加入该属性的升级项。
#   运行时 custom_key：fengliu_get_fixed_upgrade
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================

var effect_fengliu_get_highest_stat_fixed_upgrade_data = Keys.generate_hash("fengliu_get_highest_stat_fixed_upgrade_data")


var all_fixed_upgrade_id_hashs = []


# 随机抽取一个不重复的升级项
func roll_fixed_upgrade():
    var upgrade_id = Utils.get_rand_element(ItemService.fengliu_get_all_upgrade_id_hashs())
    if upgrade_id in all_fixed_upgrade_id_hashs:
        roll_fixed_upgrade()
        return

    all_fixed_upgrade_id_hashs.append(upgrade_id)


# 抽取固定升级项
func fengliu_roll_effect(player_index: int):
    var effects = RunData.get_player_effect(effect_fengliu_get_highest_stat_fixed_upgrade_data, player_index)
    if effects.size() > 0:
        all_fixed_upgrade_id_hashs.append(effects[0].get_highest_upgrade_data(player_index))

        for _index in range(3):
            roll_fixed_upgrade()
        return

    for _index in range(4):
        roll_fixed_upgrade()


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back(self)
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase(self)


# 返回数组按顺序填充描述文本 {0}~{3} 占位符：
#   [0]~[3] = 四个固定升级项名称（绿色）
func get_args(_player_index: int) -> Array:
    if all_fixed_upgrade_id_hashs.size() == 0:
        return ["[color=lime]%s[/color]" % "?", "[color=lime]%s[/color]" % "?", "[color=lime]%s[/color]" % "?",  "[color=lime]%s[/color]" % "?"]
    
    var args = []
    for upgrade_id_hashs in all_fixed_upgrade_id_hashs:
        args.append("[color=lime]%s[/color]" % tr(Keys.hash_to_string[upgrade_id_hashs].to_upper()))

    return args
