extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/action.gd"


# ============================================================
# 近战动作基类
#   在通用动作基类上增加近战类型标记；近战武器类只接受带该标记的动作。
#   具体近战动作继承本脚本，并按需覆写通用钩子。
# ============================================================


func fengliu_is_melee_action() -> bool:
	return true
