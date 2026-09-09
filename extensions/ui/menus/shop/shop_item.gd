extends ShopItem


var material_ui_icon = load("res://items/materials/material_ui.png")


var effect_fengliu_stats_stop = Keys.generate_hash("fengliu_stats_stop")
var effect_fengliu_shop_item_count = Keys.generate_hash("fengliu_shop_item_count")
var effect_fengliu_temporary_stats_stop = Keys.generate_hash("fengliu_temporary_stats_stop")
var fengliu_item_gold_value = 0 # 商品金币原价（hp_shop 会把 value 改成 ÷20 后的血量价）


# 切换到指定属性的代付图标与价格
func _fengliu_stats_shop_item_icon(stats_hash: int, ratio: int) -> void:
    var material_icon: Image = ItemService.get_stat_icon(stats_hash).get_data()
    var texture: = ImageTexture.new()
    texture.create_from_image(material_icon)
    # 切换为属性代付图标与价格
    _button.set_material_icon(texture)
    _button.set_value(int(ceil(value / float(max(1, ratio)))), int(RunData.get_stat(stats_hash, player_index)))


# 属性代付：金币足够且允许时保留金币，否则用属性代付显示
func fengliu_stats_stop(effect: Array) -> void:
    # 金币足够且允许金币购买：保持金币显示，并还原金币图标
    if RunData.get_player_gold(player_index) >= value and effect[2]:
        _button.set_material_icon(material_ui_icon, Utils.GOLD_COLOR)
        return

    _fengliu_stats_shop_item_icon(effect[0], effect[1])


# 临时代偿：用最高主属性折算代付图标与价格
func fengliu_temporary_stats_stop():
    var stats_hash = RunData.fengliu_get_highest_stat_hash(player_index)
    _fengliu_stats_shop_item_icon(stats_hash, RunData.fengliu_get_stat_ratios_from_price(stats_hash))


# 属性代付显示
func _fengliu_refresh_pay_display() -> void:
    var effects = RunData.get_player_effect(effect_fengliu_temporary_stats_stop, player_index)
    if effects is int and effects > 0:
        # 临时代偿优先：用金币原价显示/扣除（兼容 hp_shop 的 ÷20 血量价）
        value = fengliu_item_gold_value
        fengliu_temporary_stats_stop()
        return

    # 普通属性代付效果
    effects = RunData.get_player_effect(effect_fengliu_stats_stop, player_index)
    if effects is Array and effects.size() > 0:
        fengliu_stats_stop(effects[0])
        return

    # 原版 hp_shop
    if RunData.get_player_effect_bool(Keys.hp_shop_hash, player_index):
        value = fengliu_item_gold_value
        _fengliu_stats_shop_item_icon(Keys.stat_max_hp_hash, 20)
        value = int(ceil(fengliu_item_gold_value / 20.0))
        return

    # 无任何代付：还原金币图标与金币价格（避免残留临时属性图标）
    _button.set_material_icon(material_ui_icon, Utils.GOLD_COLOR)
    _button.set_value(value, RunData.get_player_currency(player_index))


# 扩展设置商店道具（记录金币原价并刷新代付显示）
func set_shop_item(p_item_data: ItemParentData, p_wave_value: int = RunData.current_wave) -> void :
    # 金币原价与基类同源计算（基类 hp_shop 分支会把 value 改成 ÷20 的血量价）
    if RunData.get_player_effect_bool(Keys.hp_shop_hash, player_index):
        fengliu_item_gold_value = ItemService.get_value(p_wave_value, p_item_data.value, player_index, true, p_item_data is WeaponData, p_item_data.my_id_hash)
        
    .set_shop_item(p_item_data, p_wave_value)
    if fengliu_item_gold_value == 0:
        fengliu_item_gold_value = value # 非 hp_shop 时 value 就是金币原价
    _fengliu_refresh_pay_display()


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


# 刷新所有商店道具的锁定按钮状态
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
    # 物品本身不可锁定时，强制禁用并隐藏，防止刷新时被重新激活
    if item_data == null or not item_data.is_lockable:
        _lock_button.disable()
        _lock_button.hide()
        return
    if _fengliu_is_lock_limit_reached() and not _fengliu_is_item_locked():
        _lock_button.disable()


# 达到锁定上限时禁止新增锁定，并在切换后刷新所有道具按钮
func change_lock_status(button_pressed: bool) -> void:
    if button_pressed and item_data != null and not item_data.is_lockable:
        return
    if button_pressed and _fengliu_is_lock_limit_reached():
        return
    .change_lock_status(button_pressed)
    _fengliu_refresh_lock_buttons()
