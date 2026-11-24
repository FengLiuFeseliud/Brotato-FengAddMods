extends Node

const MOD_ID = "FengAddMods"
const MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const EXTENSIONS_DIR = MOD_DIR + "extensions/"
const COMPAT_EXTENSIONS_DIR = EXTENSIONS_DIR + "mods/"
const CONTENT_DATA_DIR = MOD_DIR + "content_data.tres"
const CONTENT_DIR = MOD_DIR + "content_data/"
# 参与动态注册的子目录（其余目录只放子资源，不注册）
const FENGLIU_DYNAMIC_CONTENT_SUBDIRS := ["characters", "items", "weapons", "sets", "upgrades"]


# 排除不希望自动获得 mod 初始武器的角色
const FENGLIU_INJECT_EXCLUDE_CHARACTERS := [
	# 原版角色示例（带 character_ 前缀）
	# "character_well_rounded",
	"baked_potato",
	"steve"
]

# 排除不希望自动注入到初始武器池的 mod 武器（my_id 或 weapon_id）
const FENGLIU_INJECT_EXCLUDE_WEAPONS := [
	"wood_pickaxe",
	"stone_pickaxe",
	"iron_pickaxe",
	"diamond_pickaxe"
]


# 这些扩展的原版子类（Landmine / DartTrap / Turret / BuilderTurret）
# 延迟到 _ready（autoload 已存在、主场景未加载）再安装。
const FENGLIU_LATE_EXTENSIONS := [
	"entities/structures/structure.gd",
	"entities/structures/turret/turret.gd",
]


# ModLoader 在安装 turret.gd 扩展后会 reload 它的全局子类。
# 导出版里 BuilderTurret 等子类只有 .gdc（没有 .gd source），reload() 会用空源码
# 重编译成 native base 为 Reference 的空脚本，典型表现是建造者炮台生成时闪退。
# 办法：在 ModLoader 主安装之前给这些脚本各创建一个实例，让 reload() 直接返回
# ERR_ALREADY_IN_USE，从而保留原脚本；_ready 再释放实例并做无源码刷新。
const FENGLIU_TURRET_CHILD_SCRIPTS := [
	"res://entities/structures/turret/builder/builder_turret.gd",
	"res://entities/structures/turret/flame/flame_turret.gd",
	"res://entities/structures/turret/garden/garden.gd",
	"res://entities/structures/turret/wandering_bot/wandering_bot.gd",
]

var _fengliu_reload_guards := []
var zone_event_service = null



func _init():
	# 必须在 ModLoader 主安装之前创建 reload 保护实例
	_fengliu_create_reload_guards()

	# 先排除 The-BossRush 对 item_parent_data 的扩展
	_block_boss_rush_item_parent_data_extension()
	add_translations()

	# 安装 extensions 目录下的全部覆盖脚本
	ModLoaderLog.info("add extensions...", MOD_ID)
	_install_extensions_from_dir(EXTENSIONS_DIR)


# 给只有 .gdc 的炮台子类各创建一个实例，让 ModLoader 的 script.reload() 返回
# ERR_ALREADY_IN_USE，而不是用空 source 重编译成 Reference 空脚本。
func _fengliu_create_reload_guards() -> void:
	for path in FENGLIU_TURRET_CHILD_SCRIPTS:
		var script = load(path)
		if script == null or not script.can_instance():
			ModLoaderLog.warning("reload guard: cannot instance %s" % path, MOD_ID)
			continue
		var guard = script.new()
		if guard == null:
			ModLoaderLog.warning("reload guard: new() returned null for %s" % path, MOD_ID)
			continue
		_fengliu_reload_guards.append(guard)
	ModLoaderLog.info("reload guards created: %d" % _fengliu_reload_guards.size(), MOD_ID)


func _fengliu_free_reload_guards() -> void:
	for guard in _fengliu_reload_guards:
		if is_instance_valid(guard):
			guard.free()
	_fengliu_reload_guards.clear()
	ModLoaderLog.info("reload guards released.", MOD_ID)


# 强兼 The-BossRush
func _block_boss_rush_item_parent_data_extension() -> void:
	# 阻止 The-BossRush 扩展 item_parent_data.gd：替换该基类会破坏
	# ItemData / CharacterData / WeaponData 的类型继承关系，导致游戏编译脚本报
	# "item_parent_data.gd will never be an instance of ItemData"。
	# The-BossRush 加载顺序在本 mod 之前，_init 运行时它的扩展路径已排队到
	# ModLoaderStore.script_extensions，而 handle_script_extensions() 尚未执行。
	for i in range(ModLoaderStore.script_extensions.size() - 1, -1, -1):
		var ext_path: String = ModLoaderStore.script_extensions[i]
		if "/The-BossRush/" in ext_path and ext_path.ends_with("/items/global/item_parent_data.gd"):
			ModLoaderStore.script_extensions.remove(i)
			ModLoaderLog.info("Blocked item_parent_data.gd extension from The-BossRush: %s" % ext_path, MOD_ID)


func _install_extensions_from_dir(dir_path: String) -> void:
	# 目录打不开时记录错误并放弃
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		ModLoaderLog.error("Failed to open extensions directory: %s" % dir_path, MOD_ID)
		return

	# 递归子目录，逐个安装其中的扩展脚本
	dir.list_dir_begin(true, true)
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.plus_file(file_name)
		if dir.current_is_dir():
			if dir_path == EXTENSIONS_DIR and file_name == "mods":
				_install_compat_extensions(full_path)
			else:
				_install_extensions_from_dir(full_path)
		elif file_name.get_extension() == "gd":
			# 延迟列表里的扩展留到 _ready 再装（见 FENGLIU_LATE_EXTENSIONS）
			if not _is_late_extension(full_path):
				ModLoaderMod.install_script_extension(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


# 跨 mod 兼容层：extensions/mods/<mod名>/<原mod路径>
# 仅当对应 mod 激活/可加载，且镜像基类存在时才安装。
func _install_compat_extensions(compat_dir: String) -> void:
	var dir := Directory.new()
	if dir.open(compat_dir) != OK:
		ModLoaderLog.error("Failed to open compat extensions directory: %s" % compat_dir, MOD_ID)
		return

	dir.list_dir_begin(true, true)
	var mod_id := dir.get_next()
	while mod_id != "":
		if dir.current_is_dir():
			var mod_data = ModLoaderStore.mod_data.get(mod_id)
			if mod_data == null or not mod_data.is_active or not mod_data.is_loadable:
				ModLoaderLog.info("Skip compat extensions for inactive mod: %s" % mod_id, MOD_ID)
			else:
				_install_compat_mod_extensions(compat_dir.plus_file(mod_id), mod_id)
		mod_id = dir.get_next()
	dir.list_dir_end()


func _install_compat_mod_extensions(dir_path: String, mod_id: String) -> void:
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		ModLoaderLog.error("Failed to open compat mod directory: %s" % dir_path, MOD_ID)
		return

	dir.list_dir_begin(true, true)
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.plus_file(file_name)
		if dir.current_is_dir():
			_install_compat_mod_extensions(full_path, mod_id)
		elif file_name.get_extension() == "gd":
			var relative_path := full_path.trim_prefix(COMPAT_EXTENSIONS_DIR + mod_id + "/")
			var base_path := "res://mods-unpacked/" + mod_id + "/" + relative_path
			if _fengliu_resource_exists(base_path):
				ModLoaderMod.install_script_extension(full_path)
				ModLoaderLog.info("Installed compat extension: %s (mod %s)" % [full_path, mod_id], MOD_ID)
			else:
				ModLoaderLog.warning("Compat base not found, skip: %s -> %s" % [full_path, base_path], MOD_ID)
		file_name = dir.get_next()
	dir.list_dir_end()


# ModLoader 虚拟 zip 上 ResourceLoader.exists 不一定命中，补 File 检查兜底
func _fengliu_resource_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	var file = File.new()
	return file.file_exists(path)


func _is_late_extension(path: String) -> bool:
	for late_path in FENGLIU_LATE_EXTENSIONS:
		if path.ends_with(late_path):
			return true
	return false


func _install_late_extensions() -> void:
	for late_path in FENGLIU_LATE_EXTENSIONS:
		ModLoaderLog.info("install late extension: %s" % late_path, MOD_ID)
		ModLoaderMod.install_script_extension(EXTENSIONS_DIR + late_path)


func add_translations() -> void:
	ModLoaderLog.info("add translations...", MOD_ID)
	# 注册简体中文与英文两份翻译
	ModLoaderMod.add_translation(MOD_DIR + "translations/translations.zh_Hans_CN.translation")
	ModLoaderMod.add_translation(MOD_DIR + "translations/translations.en.translation")

func _ready()->void:
	_install_late_extensions()
	# 必须在 late extension 之后执行：恢复出来的 BuilderTurret 才会继承本 mod 的 turret 扩展
	_fengliu_refresh_turret_children()

	var dlc_probe_path = "res://dlcs/dlc_1/characters/builder/effects/builder_effect_1c.tres" 
	if not ResourceLoader.exists(dlc_probe_path):
		ModLoaderLog.info("DLC not load, load DLC...", MOD_ID)
		if is_instance_valid(ProgressData) and is_instance_valid(ItemService):
			ItemService.init_dlc_content()

	# 玩家效果槽里存的是效果实例的 custom_key 必须登记进原版全量序列化名单，
	# 且必须在读档之前完成（否则槽位会被原样序列化写成字典）
	_fengliu_register_effect_slot_keys()

	# 动态区域事件服务（区域内的事件，如雨）
	_init_zone_event_service()

	# 把本 mod 的武器按品阶注入到各可用角色的初始武器池（含本 mod 角色，见排除名单）。
	call_deferred("fengliu_inject_starting_weapons")


# 把初始武器注入到各可用角色的初始武器池：
#   - 本 Mod 武器：所有角色（排除名单除外），按角色原池品阶注入，带套装限制的角色只注入对应套装
#   - 原版/DLC 武器：只注入给带 fengliu_can_rand_set_weapon 的角色，且只注入该效果 key 锁定的套装
func fengliu_inject_starting_weapons() -> void:
	if not is_instance_valid(ItemService) or ItemService.characters.size() == 0 or ItemService.weapons.size() == 0:
		ModLoaderLog.warning("ItemService.characters/weapons is empty, skip starting weapon injection.", MOD_ID)
		return

	# 动态收集武器并按品阶分组：本 Mod 武器 / 原版（含 DLC）武器
	var mod_weapons_by_tier := {}
	var base_weapons_by_tier := {}
	for weapon in ItemService.weapons:
		if weapon == null or not (weapon is WeaponData):
			continue

		if weapon.resource_path.begins_with(MOD_DIR):
			# 武器排除名单：my_id 或 weapon_id 命中即跳过
			if FENGLIU_INJECT_EXCLUDE_WEAPONS.has(weapon.my_id) or FENGLIU_INJECT_EXCLUDE_WEAPONS.has(weapon.weapon_id):
				continue
			_fengliu_push_weapon_by_tier(mod_weapons_by_tier, weapon)
		elif _fengliu_is_base_weapon(weapon):
			# 诅咒武器不进入初始武器池
			if weapon.is_cursed:
				continue
			_fengliu_push_weapon_by_tier(base_weapons_by_tier, weapon)

	if mod_weapons_by_tier.size() == 0:
		ModLoaderLog.warning("No FengAddMods weapon registered in ItemService.weapons, skip injection.", MOD_ID)
		return

	# 注入前快照：角色原池品阶、套装限制、fengliu_can_rand_set_weapon 的 key 套装、缩放属性负向修改
	var character_tiers := {}
	var character_restricted_sets := {}
	var character_key_sets := {}
	var character_stat_reductions := {}
	for character in ItemService.characters:
		if character == null:
			continue

		character_tiers[character.my_id] = _fengliu_get_starting_weapon_tier(character)
		character_restricted_sets[character.my_id] = _fengliu_get_restricted_weapon_set_ids(character)
		character_stat_reductions[character.my_id] = _fengliu_get_character_stat_reductions(character)

		var key_set_ids := _fengliu_get_can_rand_set_weapon_set_ids(character)
		if key_set_ids.size() > 0:
			character_key_sets[character.my_id] = key_set_ids

	# 本 Mod 武器：所有角色（排除名单 / 武器类型冲突 / 套装限制在函数内判定）
	var reduction_counts := {}
	var mod_tier_counts := {}
	var total_mod_injected := _fengliu_inject_weapons_by_tier(mod_weapons_by_tier, character_tiers, character_restricted_sets, character_stat_reductions, false, mod_tier_counts, reduction_counts)

	# 原版（含 DLC）武器：只注入给带 fengliu_can_rand_set_weapon 的角色，且只注入 key 套装
	var base_tier_counts := {}
	var total_base_injected := _fengliu_inject_weapons_by_tier(base_weapons_by_tier, character_tiers, character_key_sets, character_stat_reductions, true, base_tier_counts, reduction_counts)

	var restricted_characters := {}
	for character_id in character_restricted_sets:
		if character_restricted_sets[character_id].size() > 0:
			restricted_characters[character_id] = character_restricted_sets[character_id]

	var total_reduction_blocked := 0
	var stat_reduction_characters := {}
	for character_id in reduction_counts:
		var blocked_count: int = int(reduction_counts[character_id])
		if blocked_count <= 0:
			continue
		total_reduction_blocked += blocked_count
		stat_reduction_characters[character_id] = {"blocked": blocked_count, "stats": character_stat_reductions[character_id]}

	ModLoaderLog.info("FengAddMods starting weapon injection finished, mod=%d, base=%d, total=%d, mod_tiers=%s, base_tiers=%s, weapon_reduction_blocked=%d, restricted_characters=%s, stat_reduction_characters=%s." % [total_mod_injected, total_base_injected, total_mod_injected + total_base_injected, str(mod_tier_counts), str(base_tier_counts), total_reduction_blocked, str(restricted_characters), str(stat_reduction_characters)], MOD_ID)


# 角色初始武器池只有单一品阶时返回该品阶；混阶、空池或取不到品阶时返回 0（沿用 t0 注入）
func _fengliu_get_starting_weapon_tier(character) -> int:
	if character.starting_weapons == null:
		return 0

	var single_tier := -1
	for starting_weapon in character.starting_weapons:
		if starting_weapon == null or not (starting_weapon is WeaponData):
			continue

		if single_tier == -1:
			single_tier = starting_weapon.tier

		elif single_tier != starting_weapon.tier:
			return 0

	return single_tier if single_tier >= 0 else 0


# 判断该角色是否可以接收这把武器
func _fengliu_can_inject_starting_weapon(character, weapon, restricted_set_ids: Array) -> bool:
	# 排除名单内的角色
	if FENGLIU_INJECT_EXCLUDE_CHARACTERS.has(character.my_id):
		return false

	var is_ranged: bool = weapon.type == WeaponData.Type.RANGED
	# 角色效果与武器类型冲突时不注入
	for effect in character.effects:
		if effect == null:
			continue

		if effect.text_key == "effect_no_weapons":
			return false

		if is_ranged and effect.key == "no_ranged_weapons":
			return false
		if not is_ranged and effect.key == "no_melee_weapons":
			return false

	# 角色带套装限制（武器类别加成 / fengliu_can_rand_set_weapon）时，只注入对应套装的武器
	if restricted_set_ids.size() > 0 and not _fengliu_weapon_has_any_set(weapon, restricted_set_ids):
		return false

	return true


# 按品阶把武器放进对应数组
func _fengliu_push_weapon_by_tier(weapons_by_tier: Dictionary, weapon) -> void:
	if not weapons_by_tier.has(weapon.tier):
		weapons_by_tier[weapon.tier] = []

	weapons_by_tier[weapon.tier].push_back(weapon)


# 是否为原版（含 DLC）武器（mods-unpacked 下的武器不算）
func _fengliu_is_base_weapon(weapon) -> bool:
	var path: String = weapon.resource_path
	return path.begins_with("res://weapons/") or path.begins_with("res://dlcs/")


# 按品阶把武器池注入给角色
# only_filtered_characters=true 时只处理 character_filter_sets 里登记过的角色（用于「原版武器仅给 key 角色」）
func _fengliu_inject_weapons_by_tier(weapons_by_tier: Dictionary, character_tiers: Dictionary, character_filter_sets: Dictionary, character_stat_reductions: Dictionary, only_filtered_characters: bool, tier_counts: Dictionary, reduction_counts: Dictionary) -> int:
	var total_injected := 0
	for tier in weapons_by_tier:
		for weapon in weapons_by_tier[tier]:
			for character in ItemService.characters:
				if character == null:
					continue

				# 只给「原初始武器池为该品阶」的角色注入
				if character_tiers.get(character.my_id, 0) != tier:
					continue

				var set_ids: Array = character_filter_sets.get(character.my_id, [])
				if only_filtered_characters and set_ids.size() == 0:
					continue

				if not _fengliu_can_inject_starting_weapon(character, weapon, set_ids):
					continue

				if _fengliu_character_has_starting_weapon(character, weapon.my_id):
					continue

				# 角色效果削减了这把武器的缩放属性 → 不注入
				var stat_reductions: Dictionary = character_stat_reductions.get(character.my_id, {})
				if _fengliu_weapon_blocked_by_stat_reduction(weapon, stat_reductions):
					reduction_counts[character.my_id] = int(reduction_counts.get(character.my_id, 0)) + 1
					continue

				character.starting_weapons.push_back(weapon)
				total_injected += 1
				tier_counts[tier] = int(tier_counts.get(tier, 0)) + 1

	return total_injected


# 是否为「X的修改」效果（StatGainsModificationEffect）
func _fengliu_is_stat_gains_modification(effect) -> bool:
	if effect is StatGainsModificationEffect:
		return true
	return "stats_modified" in effect and "stat_displayed" in effect


# 收集角色对武器缩放属性的负向修改（直接属性负值 + X的修改；排除伤害 / 百分比伤害）
func _fengliu_get_character_stat_reductions(character) -> Dictionary:
	var reductions := {}
	for effect in character.effects:
		if effect == null:
			continue

		if _fengliu_is_stat_gains_modification(effect):
			# 排除「伤害的修改 / %伤害的修改」整条效果
			var displayed := str(effect.stat_displayed)
			if displayed == "stat_damage" or displayed == "stat_percent_damage":
				continue

			if effect.value >= 0:
				continue
				
			for stat in effect.stats_modified:
				_fengliu_add_stat_reduction(reductions, str(stat), effect.value)

			continue

		# 条件性效果（custom_key 非空）视为随状态变化，不参与
		if effect.custom_key != "":
			continue

		if effect.value >= 0:
			continue

		_fengliu_add_stat_reduction(reductions, str(effect.key), effect.value)

	return reductions


func _fengliu_add_stat_reduction(reductions: Dictionary, stat: String, value: int) -> void:
	if stat == "" or stat == "stat_damage" or stat == "stat_percent_damage":
		return

	reductions[stat] = int(reductions.get(stat, 0)) + value


# 武器缩放属性（面板「缩放」）的属性名列表
func _fengliu_get_weapon_scaling_stats(weapon) -> Array:
	var stats := []
	if weapon.stats == null or weapon.stats.scaling_stats == null:
		return stats

	for entry in weapon.stats.scaling_stats:
		if entry == null or entry.size() < 1:
			continue

		var stat = entry[0]
		var stat_name := ""
		if stat is String:
			stat_name = stat

		elif stat is int or stat is float:
			stat_name = str(Keys.hash_to_string.get(int(stat), ""))

		if stat_name != "" and not stats.has(stat_name):
			stats.push_back(stat_name)

	return stats


# 武器的任一缩放属性被角色负向修改时不注入
func _fengliu_weapon_blocked_by_stat_reduction(weapon, reductions: Dictionary) -> bool:
	if reductions.size() == 0:
		return false

	for stat_name in _fengliu_get_weapon_scaling_stats(weapon):
		if reductions.has(stat_name):
			return true

	return false


# 收集角色「武器套装限制」：武器类别加成（ClassBonusEffect）+ 只允许指定套装（fengliu_can_rand_set_weapon）
func _fengliu_get_restricted_weapon_set_ids(character) -> Array:
	var set_ids := []
	for effect in character.effects:
		if effect == null:
			continue

		if _fengliu_is_class_bonus_effect(effect):
			_fengliu_push_set_id(set_ids, str(effect.set_id))
			
		elif _fengliu_is_can_rand_set_weapon_effect(effect):
			_fengliu_push_set_id(set_ids, _fengliu_get_can_rand_set_weapon_set_id(effect))

	return set_ids


# 收集角色 fengliu_can_rand_set_weapon 锁定的套装 id
func _fengliu_get_can_rand_set_weapon_set_ids(character) -> Array:
	var set_ids := []
	for effect in character.effects:
		if effect == null:
			continue

		if not _fengliu_is_can_rand_set_weapon_effect(effect):
			continue

		_fengliu_push_set_id(set_ids, _fengliu_get_can_rand_set_weapon_set_id(effect))

	return set_ids


# fengliu_can_rand_set_weapon 的锁定套装（运行时随机的效果优先取已抽中的 roll_set）
func _fengliu_get_can_rand_set_weapon_set_id(effect) -> String:
	var set_id := str(effect.key)
	if set_id == "" and "roll_set" in effect:
		var roll_set = effect.roll_set
		if roll_set != null and "my_id" in roll_set:
			set_id = str(roll_set.my_id)

	return set_id


func _fengliu_push_set_id(set_ids: Array, set_id: String) -> void:
	if set_id == "" or set_ids.has(set_id):
		return

	set_ids.push_back(set_id)


# 是否为 fengliu_can_rand_set_weapon（只允许指定套装的武器）
func _fengliu_is_can_rand_set_weapon_effect(effect) -> bool:
	if effect is CanRandSetWeapon:
		return true

	return effect.custom_key == "fengliu_can_rand_set_weapon"


# 是否为「武器类别加成」效果（兼容 ModLoader 重载脚本后类型判断失效）
func _fengliu_is_class_bonus_effect(effect) -> bool:
	if effect is ClassBonusEffect:
		return true

	if not ("set_id" in effect):
		return false

	return effect.key == "effect_weapon_class_bonus" or effect.key == "EFFECT_WEAPON_CLASS_BONUS"


# 武器是否属于给定套装（任一匹配即可）
func _fengliu_weapon_has_any_set(weapon, set_ids: Array) -> bool:
	if weapon.sets == null:
		return false

	for set in weapon.sets:
		if set == null or not ("my_id" in set):
			continue

		if set_ids.has(set.my_id):
			return true

	return false


# 该角色初始武器池中是否已有同 id 武器
func _fengliu_character_has_starting_weapon(character, weapon_my_id: String) -> bool:
	# 遍历初始武器池，存在同 id 武器即视为已拥有
	for starting_weapon in character.starting_weapons:
		if starting_weapon != null and starting_weapon.my_id == weapon_my_id:
			return true
	return false


# 登记「玩家效果槽里存效果实例」的 custom_key（必须在读档之前调用）
func _fengliu_register_effect_slot_keys() -> void:
	# RunData 未就绪时只记错误，避免读档前崩溃
	if not is_instance_valid(RunData):
		ModLoaderLog.error("RunData not ready, effect slot keys not registered.", MOD_ID)
		return

	# 幂等登记：名单在 RunData 扩展里（单一来源），已有同 key 就跳过
	for slot_key in RunData.FENGLIU_EFFECT_SLOT_KEYS:
		var slot_hash: int = Keys.generate_hash(slot_key)
		if not RunData.effect_keys_full_serialization.has(slot_hash):
			RunData.effect_keys_full_serialization.push_back(slot_hash)

	ModLoaderLog.info("Registered effect slot keys, total=%d." % RunData.effect_keys_full_serialization.size(), MOD_ID)


# ── ModLoader 子类重载兼容修复 ────────────────────────────────────────────────
# reload 保护实例在 _init 中阻止 .gdc 炮台子类被重编译成 Reference；
# 主安装结束后只对四个炮台子类做一次刷新，让它们继承最终的 turret.gd 扩展链。
var _fengliu_turret_refresh_done := false


func _fengliu_refresh_turret_children() -> void:
	if _fengliu_turret_refresh_done:
		return
	_fengliu_turret_refresh_done = true

	_fengliu_free_reload_guards()

	if not is_instance_valid(ModLoaderStore):
		ModLoaderLog.error("ModLoaderStore not ready, skip turret refresh.", MOD_ID)
		return

	for path in FENGLIU_TURRET_CHILD_SCRIPTS:
		if ModLoaderStore.saved_scripts.has(path):
			_fengliu_rebuild_script_chain(path)
		else:
			_fengliu_refresh_script_path(path)

		var current = load(path)
		if current == null or current.get_instance_base_type() == "Reference":
			ModLoaderLog.error("turret child invalid after refresh: %s" % path, MOD_ID)

	var builder_turret = load("res://entities/structures/turret/builder/builder_turret.gd")
	if builder_turret != null:
		ModLoaderLog.info("turret refresh: builder base=%s" % [builder_turret.get_instance_base_type()], MOD_ID)


func _fengliu_refresh_script_path(path: String) -> void:
	var fresh = _fengliu_load_fresh_script(path)
	if fresh == null:
		ModLoaderLog.error("turret refresh: cannot load fresh script %s" % path, MOD_ID)
		return
	fresh.take_over_path(path)
	ModLoaderLog.info("turret refresh: %s base=%s" % [path, fresh.get_instance_base_type()], MOD_ID)


# 重载原版脚本后再按原顺序重放该路径上的所有脚本扩展
func _fengliu_rebuild_script_chain(path: String) -> void:
	var extension_paths := []
	for entry in ModLoaderStore.saved_scripts.get(path, []):
		if entry == null:
			continue
		var extension_path: String = entry.get_meta("extension_script_path", "")
		if extension_path != "":
			extension_paths.push_back(extension_path)

	var fresh = _fengliu_load_fresh_script(path)
	if fresh == null:
		ModLoaderLog.error("turret refresh: cannot load fresh script %s" % path, MOD_ID)
		return

	# 先恢复原版路径，再按保存顺序重新应用扩展；apply_extension 会重新保存 base 脚本
	ModLoaderStore.saved_scripts.erase(path)
	fresh.take_over_path(path)
	for extension_path in extension_paths:
		_ModLoaderScriptExtension.apply_extension(extension_path)

	var restored = load(path)
	var restored_base := "?"
	if restored != null:
		restored_base = restored.get_instance_base_type()
	ModLoaderLog.info("turret refresh: rebuilt %s with %d extension(s), base=%s" % [path, extension_paths.size(), restored_base], MOD_ID)


# 从 pck 重新加载一份未被缓存污染的脚本；.gd 的 remap 仍命中旧缓存时退回 .gdc
func _fengliu_load_fresh_script(path: String) -> Script:
	var cached = load(path)
	var fresh = ResourceLoader.load(path, "Script", true)
	if fresh == null or fresh == cached:
		var bytecode_path := path.replace(".gd", ".gdc")
		if bytecode_path != path:
			var bytecode_script = ResourceLoader.load(bytecode_path, "Script", true)
			if bytecode_script != null:
				fresh = bytecode_script

	if fresh == null:
		return null

	# 无法绕过缓存时，只有“有源码、且不是 Reference 空脚本”的旧对象可以接受
	if cached != null and fresh == cached:
		if cached.get_source_code() != "" and cached.get_instance_base_type() != "Reference":
			return cached
		return null

	return fresh



# 动态区域事件服务：加载 zone_events/events/ 下的 .tres（雨等）
func _init_zone_event_service() -> void:
	var service_script = load("res://mods-unpacked/FengLiu-FengAddMods/zone_events/zone_event_service.gd")
	if service_script == null:
		ModLoaderLog.error("Failed to load ZoneEventService script", MOD_ID)
		return

	zone_event_service = service_script.new()
	zone_event_service.name = "ZoneEventService"
	add_child(zone_event_service)
	zone_event_service.load_events_from_dir("res://mods-unpacked/FengLiu-FengAddMods/zone_events/events/")
	ModLoaderLog.info("ZoneEventService initialized", MOD_ID)
