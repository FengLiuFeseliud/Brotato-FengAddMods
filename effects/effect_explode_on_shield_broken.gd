class_name ExplodeOnShieldBroken
extends ItemExplodingEffect


# ============================================================
# 效果：破盾爆炸
#   盾值被清空的那一击触发一次爆炸，「伤害/范围/缩放属性」全部取自 stats 指向的 WeaponStats。
#   触发点在扩展脚本 extensions/entities/units/player/player.gd 的 take_damage 破盾分支。
#   运行时 custom_key：fengliu_explode_on_shield_broken
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑；
#   触发概率与爆炸表现复用原版 ItemExplodingEffect 的字段：
#   chance                    触发概率
#   explosion_scene           爆炸场景
#   scale                     爆炸缩放
#   base_smoke_amount         烟雾数量
#   sound_db_mod              音量修正
#   stats                     WeaponStats（伤害/范围/缩放属性）
#   tracking_key              统计追踪键
#   scale_with_missing_health 是否按已损生命放大伤害
# ============================================================


static func get_id() -> String:
	return "fengliu_explode_on_shield_broken"


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).push_back(self)


func unapply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash, player_index).erase(self)
