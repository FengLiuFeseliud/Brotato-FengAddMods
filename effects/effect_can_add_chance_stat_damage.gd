class_name CanAddChanceStatDemageEffect
extends ChanceStatDamageEffect

# ============================================================
# 效果：概率触发伤害（概率可吃倍率）
#   继承 ChanceStatDamageEffect，概率触发一次基于某属性的伤害，
#   且触发概率本身可吃倍率属性。
#   运行时 custom_key：
#     fengliu_can_add_chance_stat_damage_when_pickup_gold（捡金币触发）
#     fengliu_can_add_chance_stat_damage_when_death（击杀触发）
# ------------------------------------------------------------
# 效果值（含基类 ChanceStatDamageEffect）：
#   key             伤害倍率属性（伤害 = value% × 该属性）
#   value           伤害百分比
#   chance          基础触发概率（%）
#   tracking_text   UI 追踪文本
#   add_chance_stat 概率倍率属性（提升概率所吃的属性）
#   add_chance      概率倍率（每 add_chance/100 点该属性 +1% 概率）
#   stat_no_zero    （保留，随机不为 0）
# ============================================================

# 概率触发效果 可提升概率吃倍率属性

export (String) var add_chance_stat = "" # 概率倍率属性（提升概率所吃的属性）
export (int) var add_chance = 0 # 概率倍率（每 add_chance/100 点该属性 +1% 概率）
export (bool) var stat_no_zero = false # 随机没有 0
var add_chance_stat_hash = ""


func _generate_hashes() -> void:
	._generate_hashes()
	add_chance_stat_hash = Keys.generate_hash(add_chance_stat)


static func get_id() -> String:
	return "effect_can_add_chance_stat_damage"
	

func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, chance, tracking_key, add_chance_stat_hash, add_chance, chance])
	
	
func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, chance, tracking_key, add_chance_stat_hash, add_chance, chance])
	
	
static func get_dynamic_chance(stat_count: int, init_chance: int, _add_chance: int) -> int:
	var dynamic_chance = int(init_chance + (stat_count * (_add_chance / 100.0)))
	if dynamic_chance > 100:
		return 100
		
	return dynamic_chance


func get_args(player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{3} 占位符：
	#   [0] = 动态触发概率百分比（绿色）
	#   [1] = 概率倍率属性图标文本
	#   [2] = 伤害值（基类 args[1]）
	#   [3] = 伤害倍率缩放文本（基类 args[2]）
	var args = .get_args(player_index)
	var scaling_add_chance_text = Utils.get_scaling_stat_icon_text(Keys.generate_hash(add_chance_stat), add_chance / 100.0, false)
	var stat = Utils.get_stat(add_chance_stat_hash, player_index)
	return [
		"[color=lime]%s%%[/color]" % get_dynamic_chance(stat, chance, add_chance), 
		scaling_add_chance_text, 
		args[1], 
		args[2]
	]
