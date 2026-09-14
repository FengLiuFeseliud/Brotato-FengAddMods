class_name AddStucture
extends Effect


# ============================================================
# 效果：拾取消耗品生成构造物
#   拾取消耗品时，按「基础数量 + 属性倍率」生成构造物。
#   运行时 custom_key：fengliu_picke_consumable_drop_structure
# ------------------------------------------------------------
# 效果值：
#   key             倍率属性（每 gain_value 点该属性多生成 1 个）
#   value           基础生成数量
#   gain_value      倍率（生成数 = value + 属性/gain_value 取整）
#   stucture_effect 要生成的构造物（StructureEffect 资源）
# ============================================================

export (int) var gain_value = 0 # 倍率：每多少点 key 属性多生成 1 个构造物
export (Resource) var stucture_effect # 要生成的构造物（StructureEffect 资源）
var _init_stats_args_structure :=  WeaponServiceInitStatsArgs.new()


func apply(player_index: int) -> void:
	RunData.get_player_effect(custom_key_hash ,player_index).push_back([key_hash, value, gain_value, stucture_effect])
	

func unapply(player_index: int) -> void:
	RunData.get_player_effects(player_index)[custom_key_hash].erase([key_hash, value, gain_value, stucture_effect])


func get_args(player_index: int) -> Array:
    # 返回数组按顺序填充描述文本 {0}~{5} 占位符：
    #   [0] = 基础生成数量 (value)
    #   [1] = 倍率属性名 (key)
    #   [2] = 倍率属性图标文本
    #   [3] = 构造物名称
    #   [4] = 构造物初始伤害
    #   [5] = 构造物缩放属性图标文本
    var args = .get_args(player_index)
    var scaling_stats_names = WeaponService.get_scaling_stats_icon_text(stucture_effect.stats.scaling_stats)
    var init_stats  = WeaponService.init_structure_stats(stucture_effect.stats, player_index, _init_stats_args_structure)

    return [
        args[0], 
        args[1], 
        Utils.get_scaling_stat_icon_text(key_hash, gain_value / 100.0),
        tr(stucture_effect.text_key.to_upper()),
        str(init_stats.damage),
        scaling_stats_names
    ]