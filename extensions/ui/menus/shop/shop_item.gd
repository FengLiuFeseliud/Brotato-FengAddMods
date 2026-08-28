extends ShopItem


var material_ui_icon = load("res://items/materials/material_ui.png")


var effect_fengliu_stats_stop = Keys.generate_hash("fengliu_stats_stop")
var effect_fengliu_shop_item_count = Keys.generate_hash("fengliu_shop_item_count")


# 扩展属性代付显示
func set_shop_item(p_item_data: ItemParentData, p_wave_value: int = RunData.current_wave) -> void :
    .set_shop_item(p_item_data, p_wave_value)

    # 无代付效果则跳过
    var effects = RunData.get_player_effect(effect_fengliu_stats_stop, player_index)
    if effects.size() == 0:
        return
    
    var effect = effects[0]
    # 金币足够且允许金币购买：保持金币显示，并还原金币图标（防止上一帧属性图标残留）
    if RunData.get_player_gold(player_index) >= value and effect[2]:
        _button.set_material_icon(material_ui_icon, Utils.GOLD_COLOR)
        return

    var material_icon: Image = ItemService.get_stat_icon(effect[0]).get_data()
    var texture: = ImageTexture.new()
    texture.create_from_image(material_icon)
    # 切换为属性代付图标与价格
    _button.set_material_icon(texture)
    _button.set_value(int(ceil(value / float(effect[1]))), int(RunData.get_stat(effect[0], player_index)))


# 是否达到锁定上限
func _fengliu_is_lock_limit_reached() -> bool:
    var effects = RunData.get_player_effect(effect_fengliu_shop_item_count, player_index)
    if effects.size() == 0:
        return false
    return RunData.locked_shop_items[player_index].size() >= effects[0][6]


# 当前道具是否已锁定
func _fengliu_is_item_locked() -> bool:
    if item_data == null:
        return false
    for entry in RunData.locked_shop_items[player_index]:
        if entry[0].my_id == item_data.my_id:
            return true
    return false


func _fengliu_refresh_lock_buttons() -> void:
    var parent = get_parent()
    if parent == null:
        return
    for child in parent.get_children():
        if child is ShopItem:
            child.manage_lock_button_visibility()


# 达到锁定上限时，禁用未锁定道具的锁定按钮
func manage_lock_button_visibility() -> void:
    .manage_lock_button_visibility()
    if _fengliu_is_lock_limit_reached() and not _fengliu_is_item_locked():
        _lock_button.disable()


# 达到锁定上限时禁止新增锁定，并在切换后刷新所有道具按钮
func change_lock_status(button_pressed: bool) -> void:
    if button_pressed and _fengliu_is_lock_limit_reached():
        return
    .change_lock_status(button_pressed)
    _fengliu_refresh_lock_buttons()
