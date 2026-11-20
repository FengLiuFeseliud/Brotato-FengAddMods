extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/action.gd"


# ============================================================
# 远程动作基类
#   在通用动作基类上增加远程类型标记，供后续远程武器类与远程动作使用。
#   本轮不包含任何具体远程动作。
# ============================================================


func fengliu_is_ranged_action() -> bool:
	return true
