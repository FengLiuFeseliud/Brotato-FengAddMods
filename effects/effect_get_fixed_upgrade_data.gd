class_name GetFixedUpgradeData
extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/mod_effect.gd"


# ============================================================
# 效果：固定下一波升级项
#   下一波升级时，升级属性项固定为随机抽取的若干项（定向训练）。
#   若同时拥有「必含最高属性」效果，则先加入该属性的升级项。
#   运行时 custom_key：fengliu_get_fixed_upgrade
# ------------------------------------------------------------
# 效果值：仅作为存在标记，key/value 不参与逻辑。
# ============================================================

var effect_fengliu_get_highest_stat_fixed_upgrade_data = Keys.generate_hash("fengliu_get_highest_stat_fixed_upgrade_data")


var all_fixed_upgrade_id_hashs = []


static func get_id() -> String:
	return "fengliu_get_fixed_upgrade_data"


func fengliu_persist_var_names() -> Array:
	return ["all_fixed_upgrade_id_hashs"]


# 归一化：JSON 往返会把 int 变浮点，统一转回 int，避免升级项哈希查不到
func fengliu_on_persist_vars_restored() -> void:
	var normalized := []
	# 逐项转回 int，保证升级项哈希查得到
	for upgrade_id_hash in all_fixed_upgrade_id_hashs:
		normalized.push_back(int(upgrade_id_hash))
	all_fixed_upgrade_id_hashs = normalized


# 是否已经有抽取结果
func fengliu_has_roll_data() -> bool:
	return all_fixed_upgrade_id_hashs.size() > 0


# 随机抽取一个不重复的升级项
func roll_fixed_upgrade() -> void:
	var upgrade_pool: Array = ItemService.fengliu_get_all_upgrade_id_hashs()
	# 升级项池为空（内容还没注册完）时直接放弃，避免 append(null)
	if upgrade_pool.size() == 0:
		return

	var upgrade_id = Utils.get_rand_element(upgrade_pool)
	# 已抽取过则重新抽取；池子已抽完则停止（避免无限递归）
	if upgrade_id in all_fixed_upgrade_id_hashs:
		if all_fixed_upgrade_id_hashs.size() >= upgrade_pool.size():
			return
		roll_fixed_upgrade()
		return

	all_fixed_upgrade_id_hashs.append(upgrade_id)


# 抽取固定升级项
func fengliu_roll_effect(player_index: int) -> void:
	# 升级项池为空时放弃（避免抽到 null）
	if ItemService.fengliu_get_all_upgrade_id_hashs().size() == 0:
		return

	all_fixed_upgrade_id_hashs.clear() 
	
	# 有「必含最高属性」效果时先加入最高属性升级项
	var effects = RunData.get_player_effect(effect_fengliu_get_highest_stat_fixed_upgrade_data, player_index)
	if effects.size() > 0:
		var highest_upgrade = effects[0].get_highest_upgrade_data(player_index)
		if highest_upgrade != null:
			all_fixed_upgrade_id_hashs.append(int(highest_upgrade))

		# 再随机补抽 3 个
		for _index in range(3):
			roll_fixed_upgrade()
		return

	# 无该效果则直接随机抽 4 个
	for _index in range(4):
		roll_fixed_upgrade()


func apply(player_index: int) -> void:
	# 首次生效时先抽好固定升级项
	if all_fixed_upgrade_id_hashs.size() == 0:
		fengliu_roll_effect(player_index)

	RunData.get_player_effect(custom_key_hash ,player_index).push_back(self)


func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase(self)


# 返回数组按顺序填充描述文本 {0}~{3} 占位符：
#   [0]~[3] = 四个固定升级项名称（绿色）
func get_args(player_index: int) -> Array:
	# 旧档 / 商店预览还没有抽取结果时补抽一次（正式版 base_shop 扩展可能未安装）
	if all_fixed_upgrade_id_hashs.size() == 0 and player_index >= 0 and player_index < RunData.players_data.size():
		fengliu_roll_effect(player_index)

	var args := []
	# 每项按哈希反查升级项名称，转大写翻译后上色
	for upgrade_id_hashs in all_fixed_upgrade_id_hashs:
		var upgrade_id_hash: int = int(upgrade_id_hashs)
		# 查不到名称就显示问号，避免直接索引报错
		if not Keys.hash_to_string.has(upgrade_id_hash):
			args.append("[color=lime]%s[/color]" % "?")
			continue

		args.append("[color=lime]%s[/color]" % tr(Keys.hash_to_string[upgrade_id_hash].to_upper()))

	# 补齐到 4 项，避免 {2}/{3} 占位符残留
	while args.size() < 4:
		args.append("[color=lime]%s[/color]" % "?")

	return args

