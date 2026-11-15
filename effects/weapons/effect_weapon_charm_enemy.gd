class_name WeaponCharmEnemyEffect
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_null_effect.gd"


# ============================================================
# 效果：武器命中魅惑（参考原版浪漫之人 / 长笛）
#   用该武器命中生命值低于阈值的敌人时，有概率将其魅惑。
#   概率可吃倍率属性（默认元素伤害）；精英 / Boss 不魅惑（同长笛）。
#   运行时 custom_key：fengliu_weapon_charm_enemy
#   文案复用原版 EFFECT_CHARM_BELOW_HP（{0} = 血量阈值%，{1} = 概率%，
#   {2} = 缩放图标，{3} = 魅惑秒数）
# ------------------------------------------------------------
# 效果值：
#   key          概率倍率属性（提升魅惑概率所吃的属性）
#   value        基础魅惑概率（%）
#   gain_value   概率倍率（概率 += 该属性 × gain_value/100）
#   hp_threshold 生效生命值阈值（%）
# ============================================================

export (int) var hp_threshold = 60 # 生效生命值阈值（%）：敌人当前生命低于最大生命的该比例时才判定
export (int) var gain_value = 30 # 概率倍率：概率 += 该属性 × gain_value/100


static func get_id() -> String:
	return "fengliu_weapon_charm_enemy"


func get_args(player_index: int) -> Array:
	var chance = value
	var scaling_text = ""

	# 有倍率属性时叠加属性缩放，并显示缩放图标
	if key_hash != Keys.empty_hash:
		scaling_text = Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0)
		# 主界面（未开局、没有玩家数据）只显示基础概率，避免读属性越界
		if player_index < RunData.get_player_count():
			chance = value + int(Utils.get_stat(key_hash, player_index) * (gain_value / 100.0))

	return [str(hp_threshold), str(chance), scaling_text, str(Utils.CHARM_DURATION)]
