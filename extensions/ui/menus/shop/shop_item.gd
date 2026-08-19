extends ShopItem


var effect_fengliu_stats_stop = Keys.generate_hash("fengliu_stats_stop")


# 扩展属性代付显示
func set_shop_item(p_item_data: ItemParentData, p_wave_value: int = RunData.current_wave) -> void :
    .set_shop_item(p_item_data, p_wave_value)

    # 无代付效果则跳过
    var effects = RunData.get_player_effect(effect_fengliu_stats_stop, player_index)
    if effects.size() == 0:
        return
    
    var effect = effects[0]
    if RunData.get_player_gold(player_index) >= value and effect[2]:
        return

    var material_icon: Image = ItemService.get_stat_icon(effect[0]).get_data()
    var texture: = ImageTexture.new()
    texture.create_from_image(material_icon)
    # 切换为属性代付图标与价格
    _button.set_material_icon(texture)
    _button.set_value(int(ceil(value / float(effect[1]))), RunData.get_player_currency(player_index))
    