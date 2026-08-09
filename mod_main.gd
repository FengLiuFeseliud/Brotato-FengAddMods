extends Node

const MOD_DIR = "res://mods-unpacked/FengLiu-FengAddMods/"
const EXTENSIONS_DIR = MOD_DIR + "extensions/"
const CONTENT_DATA_DIR = MOD_DIR + "content_data.tres"

func _init():
	add_translations()
	
	ModLoaderMod.install_script_extension(EXTENSIONS_DIR + "weapon/base_mod_ranged_weapon.gd")
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
	ModLoaderMod.add_translation(MOD_DIR + "translations/translations.zh_Hans_CN.translation")
	ModLoaderMod.add_translation(MOD_DIR + "translations/translations.en.translation")

func _ready()->void:
	var ContentLoader = get_node("/root/ModLoader/Darkly77-ContentLoader/ContentLoader")
	ContentLoader.load_data(CONTENT_DATA_DIR, "FengAddMods")
