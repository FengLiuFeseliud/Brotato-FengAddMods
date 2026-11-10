class_name RerollStatOnlyItem
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：纯属性道具重随
#   商店 / 箱子 / 掉落生成道具时，若该道具的全部效果都只是
#   「加减属性」，就重新随机成另一件道具。
#   运行时 custom_key：fengliu_reroll_stat_only_item
# ------------------------------------------------------------
# 效果值：
#   key      未使用（留空）
#   value    未使用（留空，判定只看实例是否存在）
# ============================================================


static func get_id() -> String:
	return "fengliu_reroll_stat_only_item"


func apply(player_index: int) -> void:
	# 实例哈希可能尚未生成，先补算再写槽位
	if custom_key_hash == Keys.empty_hash:
		_generate_hashes()

	# 效果可能未挂到任何内容上，槽位不存在时先补空数组
	var effects = RunData.get_player_effects(player_index)
	if not effects.has(custom_key_hash):
		effects[custom_key_hash] = []
	effects[custom_key_hash].push_back([key_hash, value])
	

func unapply(player_index: int) -> void:
	if custom_key_hash == Keys.empty_hash:
		_generate_hashes()

	var effects = RunData.get_player_effects(player_index)
	if not effects.has(custom_key_hash):
		return
	effects[custom_key_hash].erase([key_hash, value])
