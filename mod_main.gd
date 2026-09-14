extends Node

const MOD_ID = "FengAddMods"
const MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const EXTENSIONS_DIR = MOD_DIR + "extensions/"
const CONTENT_DATA_DIR = MOD_DIR + "content_data.tres"


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
	_block_boss_rush_item_parent_data_extension()
	add_translations()

	ModLoaderLog.info("add extensions...", MOD_ID)
	_install_extensions_from_dir(EXTENSIONS_DIR)


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

	# 把本 mod 的 t0 武器注入到各可用角色的初始武器池（含本 mod 角色，见排除名单）。
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
