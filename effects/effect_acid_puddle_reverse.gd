class_name AcidPuddleReverse
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：酸液池反转
#   玩家不再被酸液池伤害：每跳按「未受护甲的酸液伤害」回复生命
#   同时每跳对池内敌人造成伤害（value + 属性 × gain_value/100，再乘百分比伤害）
#   运行时 custom_key：fengliu_acid_puddle_reverse
# ------------------------------------------------------------
# 效果值：
#   value         每跳对池内敌人的基础伤害（回血不在此：回血 = 未受护甲酸液伤害）
#   gain_value    每 1 点 scaling_stat 增加的伤害百分比（负值 = 负进化越负越痛）
#   scaling_stat  缩放属性名（默认 stat_evolution）
# ============================================================


export (int) var gain_value: int = 100
export (String) var scaling_stat: String = "stat_evolution"

var scaling_stat_hash: int = Keys.empty_hash


static func get_id() -> String:
	return "fengliu_acid_puddle_reverse"


func _generate_hashes() -> void:
	._generate_hashes()
	scaling_stat_hash = Keys.generate_hash(scaling_stat)


func fengliu_ensure_scaling_stat_hash() -> void:
	if scaling_stat_hash == Keys.empty_hash:
		scaling_stat_hash = Keys.generate_hash(scaling_stat)


func get_final_enemy_damage(player_index: int) -> int:
	fengliu_ensure_scaling_stat_hash()
	# 与 mod 其它属性缩放效果一致：value + 属性 × gain_value/100
	var damage: int = value + int(Utils.get_stat(scaling_stat_hash, player_index) * (gain_value / 100.0))
	damage = max(1, damage)
	return WeaponService.apply_damage_bonus(damage, player_index)


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back(self)


func unapply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).erase(self)


func get_args(player_index: int) -> Array:
	# {0} = 每跳最终伤害（已含缩放与百分比伤害）
	# {1} = 缩放属性图标文本（如 -50% 进化）
	fengliu_ensure_scaling_stat_hash()
	return [
		str(get_final_enemy_damage(player_index)),
		Utils.get_scaling_stat_icon_text(scaling_stat_hash, gain_value / 100.0)
	]
