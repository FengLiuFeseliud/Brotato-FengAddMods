extends ShopItem


var stats_stop = Keys.generate_hash("stats_stop")


func set_shop_item(p_item_data: ItemParentData, p_wave_value: int = RunData.current_wave) -> void :
    .set_shop_item(p_item_data, p_wave_value)

    var effects = RunData.get_player_effect(stats_stop, player_index)
    if effects.size() == 0:
        return

    var material_icon: Image = ItemService.get_stat_icon(effects[0][0]).get_data()
    var texture: = ImageTexture.new()
    texture.create_from_image(material_icon)
    _button.set_material_icon(texture)
    _button.set_value(int(ceil(value / float(effects[0][1]))), RunData.get_player_currency(player_index))
    