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

	# 每点独立随机一项主属性
	for _i in range(value):
		RunData.add_stat(RunData.get_random_primary_stats(), 1, player_index)
		if tracking_item_hash != Keys.empty_hash:
			RunData.add_tracked_value(player_index, tracking_item_hash, 1)


# 一次性效果：移除道具不退还属性
func unapply(_player_index: int) -> void:
	pass


func get_args(_player_index: int) -> Array:
	# 返回数组按顺序填充描述文本 {0}~{1} 占位符：
	#   [0] = 随机主属性点数
	#   [1] = 触发概率（百分号由 text.gd 的 keys_needing_percent 补）
	return [str(value), str(chance)]
