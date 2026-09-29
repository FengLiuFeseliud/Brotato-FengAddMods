class_name ConvertStatOnApply
extends "res://effects/items/convert_stat_effect.gd"


# ============================================================
# 效果：应用时转换属性
#   拾取（apply）时立刻把「key」属性按「pct_converted」百分比、
#   每「value」点一组换成「to_value」点「to_stat」属性，剩余部分保留；
#   一次性结算，不随道具移除回退（与原版「互换最大最小属性」同构）。
#   复用原版 Utils.convert_stats 的口径（见 singletons/utils.gd）。
#   本效果不登记运行期槽位，custom_key 留空。
# ------------------------------------------------------------
# 效果值：
#   key            被转换的属性
#   value          每多少点被转换属性算一组
#   to_stat        转换得到的属性
#   to_value       每组转换得到多少点
#   pct_converted  参与转换的百分比（剩余 100 - pct_converted 保留）
# ============================================================


static func get_id() -> String:
	return "fengliu_convert_stat_on_apply"


func apply(player_index: int) -> void:
	# 哈希可能尚未生成（.tres 走 call_deferred），结算前补齐
	if key_hash == Keys.empty_hash or to_stat_hash == Keys.empty_hash:
		_generate_hashes()

	# 按原版口径立刻结算：扣源属性、加目标属性，永久写入 effects
	Utils.convert_stats([self], player_index)


func unapply(_player_index: int) -> void:
	# 一次性转换，不随道具移除回退
	pass
