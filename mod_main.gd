extends Node

const MOD_ID = "FengAddMods"
const MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const EXTENSIONS_DIR = MOD_DIR + "extensions/"
const CONTENT_DATA_DIR = MOD_DIR + "content_data.tres"
# 全局类目录下所有写了 class_name 的 .gd 都会自动注册为全局类，
const GLOBAL_CLASSES_DIR = MOD_DIR + "global_classes/"
const GLOBAL_CLASS_NAME_REGEX = "^class_name[ \\t]+([A-Za-z_][A-Za-z0-9_]*)"
const GLOBAL_CLASS_EXTENDS_IDENT_REGEX = "^extends[ \\t]+([A-Za-z_][A-Za-z0-9_]*)"


# 排除不希望自动获得 t0 mod 初始武器角色
const FENGLIU_T0_INJECT_EXCLUDE_CHARACTERS := [
	# 原版角色示例（带 character_ 前缀）
	# "character_well_rounded",
]

# 排除不希望自动注入到初始武器池的 t0 mod 武器（weapon_id）
const FENGLIU_T0_INJECT_EXCLUDE_WEAPONS := [
	"wood_pickaxe"
]


var _fengliu_content_loader = null


func _init():
	_register_global_classes_from_dir(GLOBAL_CLASSES_DIR)
	_block_boss_rush_item_parent_data_extension()
	add_translations()

	ModLoaderLog.info("add extensions...", MOD_ID)
	_install_extensions_from_dir(EXTENSIONS_DIR)


# 自动注册全局类
func _register_global_classes_from_dir(dir_path: String) -> void:
	var classes := []
	_collect_gd_scripts(dir_path, classes)
	if classes.empty():
		ModLoaderLog.warning("No global class script found in: %s" % dir_path, MOD_ID)
		return

	var registered := {}
	var global_classes = ProjectSettings.get_setting("_global_script_classes")
	if global_classes is Array:
		for global_class in global_classes:
			if global_class is Dictionary and global_class.has("class"):
				registered[global_class["class"]] = true

	var seen := {}
	var new_classes := []
	for candidate in classes:
		var candidate_name: String = candidate["class"]
		if registered.has(candidate_name):
			continue
		if seen.has(candidate_name):
			ModLoaderLog.warning("Duplicate class_name \"%s\" in %s and %s, kept the first one." % [candidate_name, seen[candidate_name], candidate["path"]], MOD_ID)
			continue
		seen[candidate_name] = candidate["path"]
		new_classes.append(candidate)

	if new_classes.empty():
		ModLoaderLog.info("All %d global class(es) already registered, skip." % classes.size(), MOD_ID)
		return

	ModLoaderMod.register_global_classes_from_array(new_classes)
	for new_class in new_classes:
		ModLoaderLog.info("Global class registered: %s (base: %s) -> %s" % [new_class["class"], new_class["base"], new_class["path"]], MOD_ID)
	ModLoaderLog.info("%d global class(es) registered, restart the game to use them." % new_classes.size(), MOD_ID)


# 递归收集目录下所有 .gd
func _collect_gd_scripts(dir_path: String, out: Array) -> void:
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		ModLoaderLog.error("Failed to open global classes directory: %s" % dir_path, MOD_ID)
		return

	dir.list_dir_begin(true, true)
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.plus_file(file_name)
		if dir.current_is_dir():
			_collect_gd_scripts(full_path, out)
		elif file_name.get_extension().to_lower() == "gd":
			var global_class := _parse_global_class_dict(full_path)
			if not global_class.empty():
				out.append(global_class)
		file_name = dir.get_next()
	dir.list_dir_end()


func _parse_global_class_dict(path: String) -> Dictionary:
	var file := File.new()
	if file.open(path, File.READ) != OK:
		ModLoaderLog.error("Failed to open global class script: %s" % path, MOD_ID)
		return {}

	var name_regex := RegEx.new()
	name_regex.compile(GLOBAL_CLASS_NAME_REGEX)
	var extends_regex := RegEx.new()
	extends_regex.compile(GLOBAL_CLASS_EXTENDS_IDENT_REGEX)

	var class_name_str := ""
	var base := ""
	while not file.eof_reached():
		var line := file.get_line()
		# 去掉文件开头的 UTF-8 BOM
		if not line.empty() and line.ord_at(0) == 0xFEFF:
			line = line.substr(1)
		# 只看顶层语句：跳过空行、注释、缩进行（嵌套类 / 函数体内部）
		if line.empty() or line.begins_with("#") or line.begins_with(" ") or line.begins_with("\t"):
			continue
		if class_name_str.empty():
			var name_match := name_regex.search(line)
			if name_match != null:
				class_name_str = name_match.get_string(1)
		if base.empty():
			var extends_match := extends_regex.search(line)
			if extends_match != null:
				base = extends_match.get_string(1)
		if not class_name_str.empty() and not base.empty():
			break
	file.close()

	if class_name_str.empty():
		return {}

	return {
		"base": base if not base.empty() else "Reference",
		"class": class_name_str,
		"language": "GDScript",
		"path": path,
	}


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
	var dir := Directory.new()
	if dir.open(dir_path) != OK:
		ModLoaderLog.error("Failed to open extensions directory: %s" % dir_path, MOD_ID)
		return

	dir.list_dir_begin(true, true)
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.plus_file(file_name)
		if dir.current_is_dir():
			_install_extensions_from_dir(full_path)
		elif file_name.get_extension() == "gd":
			ModLoaderMod.install_script_extension(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func add_translations() -> void:
	ModLoaderLog.info("add translations...", MOD_ID)
	ModLoaderMod.add_translation(MOD_DIR + "translations/translations.zh_Hans_CN.translation")
	ModLoaderMod.add_translation(MOD_DIR + "translations/translations.en.translation")

func _ready()->void:
	var dlc_probe_path = "res://dlcs/dlc_1/characters/builder/effects/builder_effect_1c.tres" 
	if not ResourceLoader.exists(dlc_probe_path):
		ModLoaderLog.info("DLC not load, load DLC...", MOD_ID)
		if is_instance_valid(ProgressData):
			ProgressData.load_dlc_pcks()

	var ContentLoader = get_node("/root/ModLoader/Darkly77-ContentLoader/ContentLoader")
	if ContentLoader == null:
		ModLoaderLog.error("ContentLoader not load...", MOD_ID)

	ContentLoader.load_data(CONTENT_DATA_DIR, MOD_ID)

	# 把本 mod 的 t0 武器注入到各可用角色的初始武器池（含本 mod 角色）。
	call_deferred("fengliu_inject_t0_starting_weapons")


func fengliu_inject_t0_starting_weapons() -> void:
	if not is_instance_valid(ItemService) or ItemService.characters.size() == 0 or ItemService.weapons.size() == 0:
		ModLoaderLog.warning("ItemService.characters/weapons is empty, skip t0 starting weapon injection.", MOD_ID)
		return

	_fengliu_content_loader = get_node_or_null("/root/ModLoader/Darkly77-ContentLoader/ContentLoader")
	if _fengliu_content_loader == null:
		ModLoaderLog.error("ContentLoader not found, skip t0 starting weapon injection.", MOD_ID)
		return

	# 动态收集 mod 的武器
	var t0_weapons := []
	for weapon in ItemService.weapons:
		if weapon == null or not (weapon is WeaponData):
			continue
		if weapon.tier != 0:
			continue
		if _fengliu_content_loader.lookup_modid_by_itemdata(weapon) != MOD_ID:
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
			ModLoaderLog.info("t0 starting inject: %s -> %s" % [weapon.my_id, character.my_id], MOD_ID)

		total_injected += injected_count
		ModLoaderLog.info("t0 weapon %s injected into %d characters." % [weapon.my_id, injected_count], MOD_ID)

	ModLoaderLog.info("FengAddMods t0 starting weapon injection finished, total=%d." % total_injected, MOD_ID)


# 判断该角色是否可以接收这把 t0 武器
func _fengliu_t0_can_inject(character, weapon) -> bool:
	if FENGLIU_T0_INJECT_EXCLUDE_CHARACTERS.has(character.my_id):
		return false

	var is_ranged: bool = weapon.type == WeaponData.Type.RANGED
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
	for starting_weapon in character.starting_weapons:
		if starting_weapon != null and starting_weapon.my_id == weapon_my_id:
			return true
	return false
