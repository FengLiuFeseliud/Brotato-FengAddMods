extends "res://ui/menus/run/character_selection.gd"


const FENGLIU_MOD_ID = "FengAddMods"
const FENGLIU_POTATO_WORLD_NET = preload("res://mods-unpacked/FengLiu-FengAddMods/net/potato_world_net.gd")
const FENGLIU_TITLE_PATH = "MarginContainer/VBoxContainer/Title"
const FENGLIU_TITLE_KEY = "CHARACTER_SELECTION"
const FENGLIU_ROOM_CODE_KEY = "MENU_POTATO_WORLD_ROOM_CODE"

var _fengliu_title_label: Label = null
var _fengliu_pw_session = null


# 原版 _ready 负责区域/联机等初始化，先执行原逻辑再挂标题 token
func _ready() -> void:
	._ready()
	_fengliu_pw_bind_title()


# 离开界面时断开全局会话信号
func _exit_tree() -> void:
	_fengliu_pw_unbind_session()
	._exit_tree()


# 取标题节点并监听会话就绪/关闭
func _fengliu_pw_bind_title() -> void:
	_fengliu_title_label = get_node_or_null(FENGLIU_TITLE_PATH) as Label
	if _fengliu_title_label == null:
		ModLoaderLog.warning("Character selection title not found, Potato World token hidden.", FENGLIU_MOD_ID)
		return

	var session = FENGLIU_POTATO_WORLD_NET.get_session()
	if session == null:
		_fengliu_pw_refresh_title()
		return

	_fengliu_pw_session = session
	if not session.is_connected("session_ready", self, "_fengliu_pw_on_session_ready"):
		session.connect("session_ready", self, "_fengliu_pw_on_session_ready")
	if not session.is_connected("session_closed", self, "_fengliu_pw_on_session_closed"):
		session.connect("session_closed", self, "_fengliu_pw_on_session_closed")
	_fengliu_pw_refresh_title()


func _fengliu_pw_on_session_ready(_info: Dictionary) -> void:
	_fengliu_pw_refresh_title()


func _fengliu_pw_on_session_closed(_reason: String) -> void:
	_fengliu_pw_refresh_title()


# 标题 = 翻译后的原题 +（已连接时）房间验证码
func _fengliu_pw_refresh_title() -> void:
	if _fengliu_title_label == null or not is_instance_valid(_fengliu_title_label):
		return

	var token: String = ""
	if _fengliu_pw_session != null and is_instance_valid(_fengliu_pw_session):
		token = _fengliu_pw_session.get_token()

	var title: String = Text.text(FENGLIU_TITLE_KEY)
	if token != "":
		title += "   " + Text.text(FENGLIU_ROOM_CODE_KEY) + ": " + token
	_fengliu_title_label.text = title


# 断开全局会话信号，避免挂在已释放的界面节点上
func _fengliu_pw_unbind_session() -> void:
	if _fengliu_pw_session == null or not is_instance_valid(_fengliu_pw_session):
		return
	if _fengliu_pw_session.is_connected("session_ready", self, "_fengliu_pw_on_session_ready"):
		_fengliu_pw_session.disconnect("session_ready", self, "_fengliu_pw_on_session_ready")
	if _fengliu_pw_session.is_connected("session_closed", self, "_fengliu_pw_on_session_closed"):
		_fengliu_pw_session.disconnect("session_closed", self, "_fengliu_pw_on_session_closed")
	_fengliu_pw_session = null
