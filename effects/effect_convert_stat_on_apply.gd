class_name ConvertStatOnApply
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：应用时转换属性
#   拾取（apply）时把「from_stat」属性按「pct_converted」百分比、
#   每「from_value」点一组换成「value」点「key」属性，剩余部分保留；
#   一次性结算，不随道具移除回退（unapply 为空实现，与原版 axolotl
#   「互换最大最小属性」SwapMaxMinStatEffect 同构：extends Effect + apply 内同步结算）。
#   转换口径与 singletons/utils.gd 的 Utils.convert_stats 一致，
#   但按本效果字段名（from_stat / from_value / key / value）自持实现。
#   本效果不登记运行期槽位，custom_key 留空。
# ------------------------------------------------------------
# 注意：一次性副作用靠「不落在工具 mod 的临时预览白名单类型里」规避——
#   ImprovedTooltips 会对 ConvertStatEffect / GainStatForEveryStatEffect /
#   StatGainsModificationEffect 三类在 tooltip 里成对 apply→unapply
#   （current/extensions/singletons/text.gd:1017-1027）；原版 axolotl 之所以
#   安全正因为它 extends Effect 独立成类，本效果同此写法，不再继承原版转换效果。
# ------------------------------------------------------------
# 效果值：
#   from_stat      被转换的属性
#   from_value     每多少点被转换属性算一组
#   key            转换得到的属性（基类字段）
#   value          每组转换得到多少点（基类字段）
#   pct_converted  参与转换的百分比（剩余 100 - pct_converted 保留）
# ============================================================


export(float) var pct_converted = 1.0
export(String) var from_stat = "stat_max_hp"
export(int) var from_value = 1

var from_stat_hash: int = Keys.empty_hash


static func get_id() -> String:
	return "fengliu_convert_stat_on_apply"


func _generate_hashes() -> void:
	._generate_hashes()
	from_stat_hash = Keys.generate_hash(from_stat)


func apply(player_index: int) -> void:
	if from_stat_hash == Keys.empty_hash:
		from_stat_hash = Keys.generate_hash(from_stat)
	if key_hash == Keys.empty_hash:
		key_hash = Keys.generate_hash(key)
	if from_stat_hash == Keys.empty_hash or key_hash == Keys.empty_hash or from_value <= 0:
		return

	_convert_stats(player_index)


func unapply(_player_index: int) -> void:
	# 一次性转换
	pass


func get_args(_player_index: int) -> Array:
	return [str(pct_converted), tr(from_stat.to_upper()), tr(key.to_upper()), str(from_value), str(value)]


# 与 singletons/utils.gd:645-687 的 Utils.convert_stats 口径一致，
# 字段改用本效果命名：from_stat / from_value / key / value。
func _convert_stats(player_index: int, permanent: bool = true) -> void:
	var pct = pct_converted / 100.0
	var stat_to_remove = from_stat_hash
	var stat_to_add = key_hash

	var stat_to_remove_value = RunData.get_player_gold(player_index) if stat_to_remove == Keys.materials_hash else RunData.get_stat(stat_to_remove, player_index) as int
	var nb_chunks_stat_removed = max(0, floor((stat_to_remove_value * pct) / from_value))

	if nb_chunks_stat_removed == 0:
		return

	var stat_removed_gain = RunData.get_stat_gain(stat_to_remove, player_index)
	var stat_added_gain = RunData.get_stat_gain(stat_to_add, player_index)

	var base_nb_stat_removed = nb_chunks_stat_removed * from_value
	var base_nb_stat_added = value * nb_chunks_stat_removed
	var actual_nb_stat_removed = base_nb_stat_removed
	var actual_nb_stat_added = base_nb_stat_added

	if stat_removed_gain > 0.0:
		actual_nb_stat_removed = round(base_nb_stat_removed / stat_removed_gain) as int
	if stat_added_gain > 0.0:
		actual_nb_stat_added = round(base_nb_stat_added / stat_added_gain) as int

	if stat_to_remove == Keys.materials_hash:
		RunData.remove_gold(actual_nb_stat_removed, player_index)
	else:
		if permanent:
			RunData.remove_stat(stat_to_remove, actual_nb_stat_removed, player_index)
		else:
			TempStats.remove_stat(stat_to_remove, actual_nb_stat_removed, player_index)

	if stat_to_add == Keys.materials_hash:
		RunData.add_gold(actual_nb_stat_added, player_index)
	else:
		if permanent:
			RunData.add_stat(stat_to_add, actual_nb_stat_added, player_index)
		else:
			TempStats.add_stat(stat_to_add, actual_nb_stat_added, player_index)
			RunData.emit_signal("stat_added", stat_to_add, base_nb_stat_added, 0.0, player_index)


# 旧存档兼容：旧格式把「源属性 / 每组源点数」放在基类 key / value，
# 把「目标属性 / 每组目标点数」放在自定义字段 to_stat / to_value。
func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	var legacy_custom_fields = serialized.get(FENGLIU_CUSTOM_FIELDS_KEY, null)
	if legacy_custom_fields != null and legacy_custom_fields.has("to_stat"):
		var legacy_from_stat = key
		var legacy_from_value = value
		from_stat = legacy_from_stat
		from_value = legacy_from_value
		key = String(legacy_custom_fields.get("to_stat", "stat_max_hp"))
		value = int(legacy_custom_fields.get("to_value", 1))

	from_stat_hash = Keys.generate_hash(from_stat)
	key_hash = Keys.generate_hash(key)