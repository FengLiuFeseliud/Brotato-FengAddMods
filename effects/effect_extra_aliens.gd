class_name ExtraAliens
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：波次额外出现敌群
#   每波敌袭开始时额外注入若干同种敌群，出现时间随机。
#   数量 = value + 倍率属性 × gain_value/100。
#   运行时 custom_key：fengliu_extra_aliens
# ------------------------------------------------------------
# 效果值：
#   key          数量倍率属性
#   value        基础额外敌群数量
#   gain_value   数量倍率（每 gain_value/100 点该属性 +1 个敌群）
#   aliens_group 额外注入的敌群（WaveData）
# ============================================================


export (Resource) var aliens_group
export (int) var gain_value = 0


static func get_id() -> String:
	return "fengliu_extra_aliens"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, aliens_group, value, gain_value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, aliens_group, value, gain_value])


func get_args(player_index: int) -> Array:
    # 数量 = 基础数量 + 倍率属性 × 倍率
    var size_value = value + int(Utils.get_stat(key_hash, player_index) * (gain_value / 100.0))

    # 由敌群首个单位的场景名推导名称翻译 key，无翻译时退回场景名
    var scene_id = aliens_group.wave_units_data[0].unit_scene_name.get_basename()
    var name_key: String = scene_id.to_upper() + "_NAME"
    var translated: String = tr(name_key)
    
    if translated == name_key:
        translated = scene_id
    
    return [
		"[color=lime]%s[/color]" % size_value,
		Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0),
		"[color=lime]%s[/color]" % translated
	]
