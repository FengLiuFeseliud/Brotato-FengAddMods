extends Control


# 「土豆的世界」连接代码弹层

const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_POTATO_WORLD_NET = preload("res://mods-unpacked/FengLiu-FengAddMods/net/potato_world_net.gd")

signal connect_requested(code)
signal closed

onready var _title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
onready var _code_input: LineEdit = $CenterContainer/VBoxContainer/CodeInput
onready var _connect_button: Button = $CenterContainer/VBoxContainer/ConnectButton
onready var _status_label: Label = $CenterContainer/VBoxContainer/StatusLabel

var _fengliu_pw_session = null


func _ready() -> void:
	hide()
	_fengliu_apply_static_texts()
	_status_label.hide()
	_connect_button.connect("pressed", self, "_on_ConnectButton_pressed")
	_code_input.connect("text_entered", self, "_on_CodeInput_text_entered")
	_fengliu_connect_session_signals()

	# 焦点在弹层内循环，避免键盘/手柄把焦点移回后面的主菜单
	_code_input.focus_neighbour_top = _code_input.get_path()
	_code_input.focus_neighbour_left = _code_input.get_path()
	_code_input.focus_neighbour_right = _code_input.get_path()
	_code_input.focus_neighbour_bottom = _connect_button.get_path()
	_connect_button.focus_neighbour_top = _code_input.get_path()
	_connect_button.focus_neighbour_bottom = _connect_button.get_path()
	_connect_button.focus_neighbour_left = _connect_button.get_path()
	_connect_button.focus_neighbour_right = _connect_button.get_path()


# 打开弹层并清空上一次输入
func open() -> void:
	# 兜底：弹层还没进入场景树（onready 未初始化）时直接返回，避免空引用报错
	if _code_input == null:
		return
	_code_input.text = ""
	_status_label.hide()
	show()
	_code_input.grab_focus()


# ESC 关闭（由主菜单把焦点还给入口按钮）
func close() -> void:
	hide()
	emit_signal("closed")


# ---- 状态文案与全局会话 -------------------------------------------------


# 统一的状态文案入口（传翻译 key）
func set_status(text_key: String) -> void:
	if _status_label == null:
		return
	_status_label.text = Text.text(text_key)
	_status_label.show()


# 弹层里的静态文案在场景里存的是翻译 key，这里统一翻译
func _fengliu_apply_static_texts() -> void:
	_title_label.text = Text.text("MENU_POTATO_WORLD_TITLE")
	_code_input.placeholder_text = Text.text("MENU_POTATO_WORLD_CODE_PLACEHOLDER")
	_connect_button.text = Text.text("MENU_POTATO_WORLD_CONNECT")


# 监听全局会话状态：弹层关闭后会话继续存在，状态变化时回写文案
func _fengliu_connect_session_signals() -> void:
	var session = FENGLIU_POTATO_WORLD_NET.get_session()
	if session == null:
		return
	_fengliu_pw_session = session
	if not session.is_connected("session_ready", self, "_fengliu_on_pw_session_ready"):
		session.connect("session_ready", self, "_fengliu_on_pw_session_ready")
	if not session.is_connected("error_received", self, "_fengliu_on_pw_error"):
		session.connect("error_received", self, "_fengliu_on_pw_error")
	if not session.is_connected("session_closed", self, "_fengliu_on_pw_session_closed"):
		session.connect("session_closed", self, "_fengliu_on_pw_session_closed")


# 弹层销毁时断开监听，避免信号挂在已释放的节点上
func _fengliu_disconnect_session_signals() -> void:
	if _fengliu_pw_session == null or not is_instance_valid(_fengliu_pw_session):
		return
	if _fengliu_pw_session.is_connected("session_ready", self, "_fengliu_on_pw_session_ready"):
		_fengliu_pw_session.disconnect("session_ready", self, "_fengliu_on_pw_session_ready")
	if _fengliu_pw_session.is_connected("error_received", self, "_fengliu_on_pw_error"):
		_fengliu_pw_session.disconnect("error_received", self, "_fengliu_on_pw_error")
	if _fengliu_pw_session.is_connected("session_closed", self, "_fengliu_on_pw_session_closed"):
		_fengliu_pw_session.disconnect("session_closed", self, "_fengliu_on_pw_session_closed")
	_fengliu_pw_session = null


func _exit_tree() -> void:
	_fengliu_disconnect_session_signals()


func _fengliu_on_pw_session_ready(info: Dictionary) -> void:
	set_status("MENU_POTATO_WORLD_CONNECTED")
	ModLoaderLog.info(
		"Potato World session ready: %s:%d" % [info.get("host", ""), int(info.get("port", 0))],
		FENGLIU_MOD_ID
	)


func _fengliu_on_pw_error(code: String, message: String) -> void:
	# 地址格式错误单独提示，其余统一按连接失败处理
	if code == "invalid_address" or code == "invalid_port" or code == "empty":
		set_status("MENU_POTATO_WORLD_INVALID_ADDRESS")
	else:
		set_status("MENU_POTATO_WORLD_CONNECT_FAILED")
	ModLoaderLog.warning("Potato World error [%s] %s" % [code, message], FENGLIU_MOD_ID)


func _fengliu_on_pw_session_closed(_reason: String) -> void:
	set_status("MENU_POTATO_WORLD_DISCONNECTED")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_released("ui_cancel"):
		close()
		get_tree().set_input_as_handled()


func _on_ConnectButton_pressed() -> void:
	var code: String = _code_input.text.strip_edges()
	if code == "":
		set_status("MENU_POTATO_WORLD_CODE_EMPTY")
		_code_input.grab_focus()
		return

	set_status("MENU_POTATO_WORLD_CONNECTING")
	emit_signal("connect_requested", code)


func _on_CodeInput_text_entered(_text: String) -> void:
	_on_ConnectButton_pressed()
