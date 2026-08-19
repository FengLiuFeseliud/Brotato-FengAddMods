class_name TurretPriorityAttackHighestHpEffect
extends Effect


# ============================================================
# 效果：炮塔优先攻击最高血量目标
#   炮塔优先攻击血量最高的目标。
#   运行时 custom_key：fengliu_turret_prioriy_attack_highest_hp
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value])

