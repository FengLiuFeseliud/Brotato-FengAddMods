extends Node

const MOD_ID = "FengAddMods"
const MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const EXTENSIONS_DIR = MOD_DIR + "extensions/"
const CONTENT_DATA_DIR = MOD_DIR + "content_data.tres"

func _init():
	add_translations()

	ModLoaderLog.info("add extensions...", MOD_ID)
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "weapon/weapon.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "entities/structures/turret/turret.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "entities/structures/structure.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "entities/units/neutral/neutral.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "singletons/run_data.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "singletons/item_service.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "ui/menus/shop/base_shop.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "ui/menus/shop/shop_item.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "entities/units/player/player.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "item/consumables/consumable.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "zones/wave_manager.gd")
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "main.gd")


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
