class_name RandomPrimaryStatsOnObtain
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：获得时随机主属性
#   获得道具时掷一次概率，命中则随机分配 <value> 点主属性（每点独立随机）。
#   一次性永久生效，unapply 不回退。
#   运行时 custom_key：fengliu_random_primary_stats_on_obtain
# ------------------------------------------------------------
# 效果值：
#   value             随机主属性点数
#   chance            触发概率（%）
#   tracking_item_id  统计记到哪个道具（道具 my_id，如 item_mysterious_potion；空=不记录）
# ============================================================

# 获得时随机主属性

export (int) var chance = 40 # 触发概率（%）
export (String) var tracking_item_id = "" # 统计道具 id
var tracking_item_hash: int = Keys.empty_hash

var effect_fengliu_gain_random_primary_stats_on_obtain_hash = Keys.generate_hash("fengliu_gain_random_primary_stats_on_obtain")


static func get_id() -> String:
	return "fengliu_random_primary_stats_on_obtain"


func _generate_hashes() -> void:
	._generate_hashes()
	tracking_item_hash = Keys.generate_hash(tracking_item_id)


func apply(player_index: int) -> void:
	# 概率未配置时不触发
	if chance <= 0:
		return

	# 概率判定（上限 100%）
	if not Utils.get_chance_success(min(chance, 100) / 100.0):
		return

	# 读取概率
	var double_chance := 0
	var debuff_chance := 0
	var gain_entries = RunData.get_player_effect(effect_fengliu_gain_random_primary_stats_on_obtain_hash, player_index)
	if gain_entries is Array:
		for entry in gain_entries:
			if entry is Array and entry.size() >= 2:
				double_chance += int(entry[0])
				debuff_chance += int(entry[1])

	double_chance = min(double_chance, 100)
	debuff_chance = min(debuff_chance, 100)

	var per_point := 1
	if double_chance > 0 and Utils.get_chance_success(double_chance / 100.0):
		# value% 翻倍
		per_point = 2
	elif debuff_chance > 0 and Utils.get_chance_success(debuff_chance / 100.0):
		# 增加改为减
		per_point = -1
		# 下一波 1 血开始
		RunData.get_player_effects(player_index)[Keys.hp_start_next_wave_hash] = -100

	# 每点独立随机一项主属性
	for _i in range(value):
		RunData.add_stat(RunData.get_random_primary_stats(), per_point, player_index)
		if tracking_item_hash != Keys.empty_hash:
			RunData.add_tracked_value(player_index, tracking_item_hash, per_point)


# 一次性效果：移除道具不退还属性
func unapply(_player_index: int) -> void:
	pass


func get_args(_player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{1} 占位符：
	#   [0] = 随机主属性点数
	#   [1] = 触发概率（百分号由 text.gd 的 keys_needing_percent 补）
	return [str(value), str(chance)]
