extends "res://ui/menus/pages/main_menu.gd"


# 主界面「土豆的世界」入口：在「开始」按钮正下方插入入口，并弹出连接代码界面。

const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_POTATO_WORLD_BUTTON_NAME = "PotatoWorldButton"
const FENGLIU_POTATO_WORLD_POPUP_SCENE = "res://mods-unpacked/FengLiu-FengAddMods/ui/potato_world/potato_world_popup.tscn"
const FENGLIU_POTATO_WORLD_NET = preload("res://mods-unpacked/FengLiu-FengAddMods/net/potato_world_net.gd")
# 连接成功后给「已连接到土豆的世界」留一点展示时间，再切到角色选择
const FENGLIU_POTATO_WORLD_REDIRECT_DELAY = 0.35

var _fengliu_potato_world_button: Button = null
var _fengliu_potato_world_popup = null
var _fengliu_pw_session = null
var _fengliu_potato_world_redirecting: = false


# 扩展初始化
func _ready() -> void:
	# 控制台版菜单会在 setup_console_common() 里按固定索引移动按钮，
	# 插入新按钮会打乱原有顺序，因此在控制台构建下不添加
	if Utils.is_on_console():
		return

	_fengliu_add_potato_world_button()
	_fengliu_create_potato_world_popup()


# 在「开始」按钮后插入「土豆的世界」按钮
func _fengliu_add_potato_world_button() -> void:
	if left_container == null or start_button == null:
		ModLoaderLog.error("Main menu buttons not found, Potato World button skipped.", FENGLIU_MOD_ID)
		return

	# 重复进入主菜单时避免重复插入
	var existing = left_container.get_node_or_null(FENGLIU_POTATO_WORLD_BUTTON_NAME)
	if existing != null:
		_fengliu_potato_world_button = existing
		return

	var button: Button = Button.new()
	button.name = FENGLIU_POTATO_WORLD_BUTTON_NAME
	# 文案走翻译 key（en: Potato World / zh: 土豆的世界）
	button.text = Text.text("MENU_POTATO_WORLD")
	button.align = Button.ALIGN_LEFT
	button.rect_min_size = Vector2(0, 80)
	button.focus_neighbour_left = NodePath("../../ButtonsRight/ModsButton")
	button.focus_neighbour_right = NodePath("../../ButtonsRight/ModsButton")
	button.focus_neighbour_top = NodePath("../StartButton")
	button.focus_neighbour_bottom = NodePath("../ProfileButton")
	# 挂上与其它菜单按钮相同的脚本，保持悬停/按下音效一致
	# 用 load() 而不是 preload()：避免 check-only 下的类解析顺序报错
	var menu_button_script = load("res://ui/menus/global/my_menu_button.gd")
	if menu_button_script != null:
		button.set_script(menu_button_script)
	button.connect("pressed", self, "_fengliu_on_potato_world_button_pressed")

	left_container.add_child(button)
	# 紧跟「开始」按钮（VBoxContainer 会自动重排后续按钮）
	left_container.move_child(button, start_button.get_index() + 1)
	_fengliu_potato_world_button = button

	# 键盘/手柄上下导航经过新按钮
	start_button.focus_neighbour_bottom = button.get_path()
	if profile_button != null:
		profile_button.focus_neighbour_top = button.get_path()


# 创建连接代码弹层，挂在标题界面根节点上以覆盖整屏
func _fengliu_create_potato_world_popup() -> void:
	var popup_scene = load(FENGLIU_POTATO_WORLD_POPUP_SCENE)
	if popup_scene == null:
		ModLoaderLog.error("Failed to load Potato World popup scene.", FENGLIU_MOD_ID)
		return

	_fengliu_potato_world_popup = popup_scene.instance()
	_fengliu_potato_world_popup.connect("closed", self, "_fengliu_on_potato_world_popup_closed")
	_fengliu_potato_world_popup.connect("connect_requested", self, "_fengliu_on_potato_world_connect_requested")

	# main_menu._ready() 运行在 TitleScreen 的 ready 传播过程中，此时
	# TitleScreen.blocked > 0，直接 add_child() 会被引擎拒绝：
	# "Parent node is busy setting up children, add_node() failed."
	# 弹层会因此永远进不了场景树（onready 变量全为 null），
	# 点击入口后 open() 就会报 Invalid set index 'text' (on base: 'Nil')。
	# 用 call_deferred 推迟到空闲帧再挂载。
	call_deferred("_fengliu_attach_potato_world_popup", _fengliu_potato_world_popup)


# 空闲帧里真正挂载弹层（幂等：避免重复挂载或残留旧弹层）
func _fengliu_attach_potato_world_popup(popup) -> void:
	if not is_instance_valid(popup):
		return
	if popup.get_parent() != null:
		return

	var parent_node: Control = _fengliu_get_top_control()
	if parent_node == null or parent_node == popup:
		parent_node = self

	# 理论上同一时刻只会有一个弹层；若父节点里已有旧的同名弹层先清掉
	var existing = parent_node.get_node_or_null("PotatoWorldPopup")
	if existing != null and existing != popup:
		existing.queue_free()

	parent_node.add_child(popup)

	# 挂载失败说明弹层仍无法进入场景树，提前报错而不是等到点击时才崩
	if popup.get_parent() == null:
		ModLoaderLog.error("Failed to attach Potato World popup to the title screen.", FENGLIU_MOD_ID)
	else:
		ModLoaderLog.info("Potato World popup attached, inside_tree=%s" % popup.is_inside_tree(), FENGLIU_MOD_ID)


# 取当前场景最顶层节点（标题界面），弹层作为它的子节点才能覆盖整屏
func _fengliu_get_top_control() -> Control:
	var node: Node = self
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node as Control


func _fengliu_on_potato_world_button_pressed() -> void:
	if _fengliu_potato_world_popup == null:
		return
	_fengliu_potato_world_popup.open()


func _fengliu_on_potato_world_popup_closed() -> void:
	if _fengliu_potato_world_button != null and is_instance_valid(_fengliu_potato_world_button):
		_fengliu_potato_world_button.grab_focus()


func _fengliu_on_potato_world_connect_requested(code: String) -> void:
	ModLoaderLog.info("Potato World connect requested, code=%s" % code, FENGLIU_MOD_ID)

	# 监听本次连接的会话：join 成功后直接进入角色选择
	_fengliu_listen_potato_world_session()

	if not FENGLIU_POTATO_WORLD_NET.connect_with_code(code):
		if _fengliu_potato_world_popup != null:
			_fengliu_potato_world_popup.set_status("MENU_POTATO_WORLD_INVALID_ADDRESS")
		return
		
	if _fengliu_potato_world_popup != null:
		_fengliu_potato_world_popup.set_status("MENU_POTATO_WORLD_CONNECTING")


# 只在玩家从主菜单发起连接时监听，避免回标题界面时被后台重连误触发跳转
func _fengliu_listen_potato_world_session() -> void:
	var session = FENGLIU_POTATO_WORLD_NET.get_session()
	if session == null:
		ModLoaderLog.error("Potato World session is unavailable.", FENGLIU_MOD_ID)
		return

	_fengliu_pw_session = session
	if not session.is_connected("session_ready", self, "_fengliu_on_potato_world_session_ready"):
		session.connect("session_ready", self, "_fengliu_on_potato_world_session_ready")


# 与 MC 侧 BroWorld 的 join 成功回调：显示状态后进入角色选择
func _fengliu_on_potato_world_session_ready(info: Dictionary) -> void:
	if _fengliu_potato_world_redirecting:
		return
	_fengliu_potato_world_redirecting = true

	if _fengliu_potato_world_popup != null and is_instance_valid(_fengliu_potato_world_popup):
		_fengliu_potato_world_popup.set_status("MENU_POTATO_WORLD_CONNECTED")

	ModLoaderLog.info(
		"Potato World connected (%s:%d), entering character selection." % [
			str(info.get("host", "")),
			int(info.get("port", 0)),
		],
		FENGLIU_MOD_ID
	)
	call_deferred("_fengliu_enter_character_selection")


# 复用「开始游戏」的流程进入角色选择；会话节点常驻，切场景后仍然可用
func _fengliu_enter_character_selection() -> void:
	if not is_inside_tree():
		return
	if FENGLIU_POTATO_WORLD_REDIRECT_DELAY > 0.0:
		yield(get_tree().create_timer(FENGLIU_POTATO_WORLD_REDIRECT_DELAY), "timeout")
	if not is_inside_tree():
		return

	if _fengliu_potato_world_popup != null and is_instance_valid(_fengliu_potato_world_popup):
		_fengliu_potato_world_popup.hide()

	MusicManager.tween( - 5)
	ProgressData.start_activity()
	var error: int = get_tree().change_scene(MenuData.character_selection_scene)
	if error != OK:
		_fengliu_potato_world_redirecting = false
		ModLoaderLog.error("Failed to open character selection (error=%d)." % error, FENGLIU_MOD_ID)


func _exit_tree() -> void:
	_fengliu_disconnect_potato_world_session()


func _fengliu_disconnect_potato_world_session() -> void:
	if _fengliu_pw_session == null or not is_instance_valid(_fengliu_pw_session):
		return
	if _fengliu_pw_session.is_connected("session_ready", self, "_fengliu_on_potato_world_session_ready"):
		_fengliu_pw_session.disconnect("session_ready", self, "_fengliu_on_potato_world_session_ready")
	_fengliu_pw_session = null
