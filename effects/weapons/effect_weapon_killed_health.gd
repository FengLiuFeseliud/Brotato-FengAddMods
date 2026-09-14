class_name WeaponKilledHealth
extends NullEffect


# ============================================================
# 效果：武器击杀治疗
#   用该武器击杀敌人时，有概率治疗所有玩家。
#   触发概率与治疗量均可吃倍率属性。
#   运行时 custom_key：fengliu_weapon_killed_health
# ------------------------------------------------------------
# 效果值：
#   key                概率倍率属性（提升触发概率所吃的属性）
#   value              基础触发概率（%）
#   gain_value         概率倍率（每 gain_value/100 点该属性 +1% 概率）
#   health_value       基础治疗量
#   health_gain_stat   治疗量倍率属性
#   health_gain_value  治疗量倍率（治疗量 += 该属性 × health_gain_value/100）
# ============================================================

export (int) var gain_value = 0 # 概率倍率：每 gain_value/100 点 key 属性 +1% 概率
export (int) var health_value = 1 # 基础治疗量
export (String) var health_gain_stat = "" # 治疗量倍率属性
export (int) var health_gain_value = 0 # 治疗量倍率：治疗量 += 该属性 × health_gain_value/100
var health_gain_stat_hash # 治疗量倍率属性哈希


func _generate_hashes() -> void:
	._generate_hashes()
	health_gain_stat_hash = Keys.generate_hash(health_gain_stat)


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{3} 占位符：
    #   [0] = 动态触发概率百分比（绿色）
    #   [1] = 概率倍率属性图标文本
    #   [2] = 当前治疗量
    #   [3] = 治疗量倍率属性图标文本
    var dynamic_chance = value + (Utils.get_stat(key_hash, player_index) * (gain_value / 100.0))
    if dynamic_chance > 100:
        dynamic_chance = 100
    
    var health = health_value + int(Utils.get_stat(health_gain_stat_hash, player_index) * (health_gain_value / 100.0))
    return [
        "[color=lime]%s%%[/color]" % dynamic_chance, 
        Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0),
        str(health),
        Utils.get_scaling_stat_icon_text(health_gain_stat_hash, health_gain_value / 100.0)
    ]  