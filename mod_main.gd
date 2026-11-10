extends Node

const MOD_ID = "FengAddMods"
const MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const EXTENSIONS_DIR = MOD_DIR + "extensions/"
const CONTENT_DATA_DIR = MOD_DIR + "content_data.tres"
const CONTENT_DIR = MOD_DIR + "content_data/"
# 参与动态注册的子目录（其余目录只放子资源，不注册）
const FENGLIU_DYNAMIC_CONTENT_SUBDIRS := ["characters", "items", "weapons", "sets", "upgrades"]


# 排除不希望自动获得 t0 mod 初始武器角色
const FENGLIU_T0_INJECT_EXCLUDE_CHARACTERS := [
	# 原版角色示例（带 character_ 前缀）
	# "character_well_rounded",
	"cleaner",
	"baked_potato",
	"blood_bull",
	"steve",
	"spitter"
]

# 排除不希望自动注入到初始武器池的 t0 mod 武器（weapon_id）
const FENGLIU_T0_INJECT_EXCLUDE_WEAPONS := [
	"wood_pickaxe"
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
			_install_extensions_from_dir(full_path)
		elif file_name.get_extension() == "gd":
			# 延迟列表里的扩展留到 _ready 再装（见 FENGLIU_LATE_EXTENSIONS）
			if not _is_late_extension(full_path):
				ModLoaderMod.install_script_extension(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


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

	# 把本 mod 的 t0 武器注入到各可用角色的初始武器池（含本 mod 角色，见排除名单）。
	call_deferred("fengliu_inject_t0_starting_weapons")


# 注：宠物伤害说明效果的原型注册已移入 extensions/singletons/item_service.gd 的 _enter_tree()，
# 因为它必须早于原生注册触发的那次读档（详见该文件注释）。
func fengliu_inject_t0_starting_weapons() -> void:
	if not is_instance_valid(ItemService) or ItemService.characters.size() == 0 or ItemService.weapons.size() == 0:
		ModLoaderLog.warning("ItemService.characters/weapons is empty, skip t0 starting weapon injection.", MOD_ID)
		return

	# 动态收集 mod 的武器（1.2.0：按资源路径前缀识别，不再依赖 ContentLoader）
	var t0_weapons := []
	for weapon in ItemService.weapons:
		if weapon == null or not (weapon is WeaponData):
			continue
		if weapon.tier != 0:
			continue
		if not weapon.resource_path.begins_with(MOD_DIR):
			continue
		# 武器排除名单：my_id 或 weapon_id 命中即跳过
		if FENGLIU_T0_INJECT_EXCLUDE_WEAPONS.has(weapon.my_id) or FENGLIU_T0_INJECT_EXCLUDE_WEAPONS.has(weapon.weapon_id):
			continue
		t0_weapons.push_back(weapon)

	if t0_weapons.size() == 0:
		ModLoaderLog.warning("No FengAddMods t0 weapon registered in ItemService.weapons, skip injection.", MOD_ID)
		return

	var total_injected := 0
	for weapon in t0_weapons:
		var injected_count := 0
		for character in ItemService.characters:
			if character == null:
				continue

			if not _fengliu_t0_can_inject(character, weapon):
				continue
				
			if _fengliu_t0_character_has_weapon(character, weapon.my_id):
				continue

			character.starting_weapons.push_back(weapon)
			injected_count += 1

		total_injected += injected_count

	ModLoaderLog.info("FengAddMods t0 starting weapon injection finished, total=%d." % total_injected, MOD_ID)


# 判断该角色是否可以接收这把 t0 武器
func _fengliu_t0_can_inject(character, weapon) -> bool:
	# 排除名单内的角色
	if FENGLIU_T0_INJECT_EXCLUDE_CHARACTERS.has(character.my_id):
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

	return true


# 该角色初始武器池中是否已有同 id 武器
func _fengliu_t0_character_has_weapon(character, weapon_my_id: String) -> bool:
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
