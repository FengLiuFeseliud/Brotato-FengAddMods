extends Reference

# 「线条空间」护眼层：在战斗画面上叠一层淡黄半透明滤镜

const NODE_NAME = "FengliuEyeCareOverlay"
const RECT_NAME = "Rect"
const SHOP_RECT_NAME = "FengliuEyeCareRect"
const SHOP_BACKGROUND_NAME = "Background"
const OVERLAY_LAYER = 0
const OVERLAY_COLOR = Color( 1.0, 0.86, 0.62, 0.32 )
const ENABLED = true
const LOG_ID = "FengAddMods"


# 开关护眼层：enabled 为假时清掉可能残留的节点
static func apply(host: Node, enabled: bool) -> void :
	if host == null:
		return

	var overlay = host.get_node_or_null(NODE_NAME)

	if not enabled or not ENABLED:
		clear(host)
		return

	# 幂等：节点已存在就只刷新层值与颜色
	if overlay != null:
		overlay.layer = OVERLAY_LAYER
		var old_rect = overlay.get_node_or_null(RECT_NAME)
		if old_rect != null:
			old_rect.color = OVERLAY_COLOR
		return

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = NODE_NAME
	layer.layer = OVERLAY_LAYER
	host.add_child(layer)

	# 全屏覆盖且鼠标穿透：不能吞掉 HUD 的点击
	var rect: ColorRect = ColorRect.new()
	rect.name = RECT_NAME
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.color = OVERLAY_COLOR
	layer.add_child(rect)

	ModLoaderLog.info("Eye care overlay applied: layer=%d color=%s" % [OVERLAY_LAYER, str(OVERLAY_COLOR)], LOG_ID)


# 移除护眼层：切到其它区域或关闭护眼时调用
static func clear(host: Node) -> void :
	if host == null:
		return

	# 只移除护眼层，不动场景里的其它节点
	var overlay = host.get_node_or_null(NODE_NAME)
	if overlay != null:
		overlay.queue_free()


# 商店背景也叠护眼层：插在 Background 之后 ⇒ 背景之上、两侧 UI（Content/PauseMenu）之下
static func apply_shop(shop: Control, enabled: bool) -> void :
	if shop == null:
		return

	var rect = shop.get_node_or_null(SHOP_RECT_NAME)

	if not enabled or not ENABLED:
		if rect != null:
			rect.queue_free()
		return

	var background = shop.get_node_or_null(SHOP_BACKGROUND_NAME)
	if background == null:
		return

	if rect == null:
		rect = ColorRect.new()
		rect.name = SHOP_RECT_NAME
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		shop.add_child(rect)

	rect.color = OVERLAY_COLOR
	# 紧跟 Background，保证低于 PauseMenu / Content（两侧 UI）
	shop.move_child(rect, background.get_index() + 1)
	ModLoaderLog.info("Eye care overlay applied to shop: index=%d color=%s" % [background.get_index() + 1, str(OVERLAY_COLOR)], LOG_ID)
