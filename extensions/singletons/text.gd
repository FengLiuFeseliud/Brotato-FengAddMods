extends "res://singletons/text.gd"


# 自定义属性补登记运算符：效果描述才会显示「+2 盾值」而不是只有「盾值」
func _enter_tree() -> void:
	for key in ["stat_fengliu_shield", "info_pos_stat_fengliu_shield", "info_neg_stat_fengliu_shield"]:
		if not keys_needing_operator.has(key):
			keys_needing_operator[key] = [0]
