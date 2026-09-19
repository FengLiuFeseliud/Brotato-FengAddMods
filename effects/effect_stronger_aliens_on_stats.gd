class_name StrongerAliensOnStats
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：指定敌人血量提升
#   指定 enemy_id 的敌人出生时按比例提升血量。
#   提升比例 = value + 倍率属性 × gain_value/100（%）。
#   运行时 custom_key：fengliu_stronger_aliens_on_stats
# ------------------------------------------------------------
# 效果值：
#   key        比例倍率属性
#   value      基础血量提升比例（%）
#   gain_value 比例倍率（每 gain_value/100 点该属性 +1% 比例）
#   enemy_id   生效的敌人 ID（如 evil_mob）
# ============================================================


export (int) var gain_value = 0
export (String) var enemy_id = ""
var enemy_id_hash = 0


static func get_id() -> String:
	return "fengliu_stronger_aliens_on_stats"


func _generate_hashes() -> void:
    # 预生成敌人 ID 哈希
    ._generate_hashes()
    enemy_id_hash = Keys.generate_hash(enemy_id)


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, gain_value, enemy_id_hash])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, gain_value, enemy_id_hash])


func get_args(player_index: int) -> Array:
    # 血量提升比例 = 基础比例 + 倍率属性 × 倍率
    var add_hp = value + int(Utils.get_stat(key_hash, player_index) * (gain_value / 100.0))
    return [
        tr(("%s_NAME" % enemy_id).to_upper()),
		"[color=lime]%s%%[/color]" % add_hp,
		Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)
	]
