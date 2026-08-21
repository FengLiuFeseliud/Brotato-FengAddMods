extends Node

const MOD_ID = "FengAddMods"
const MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const EXTENSIONS_DIR = MOD_DIR + "extensions/"
const CONTENT_DATA_DIR = MOD_DIR + "content_data.tres"

func _init():
	add_translations()

	ModLoaderLog.info("add extensions...", MOD_ID)
	_install_extensions_from_dir(EXTENSIONS_DIR)


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
