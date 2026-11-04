extends Reference


# ============================================================
# 「土豆的世界」会话的全局访问器
#   用法：
#     const PotatoWorldNet = preload("res://mods-unpacked/FengLiu-FengAddMods/net/potato_world_net.gd")
#     PotatoWorldNet.connect_with_code("192.168.1.10:8080")
#     PotatoWorldNet.send_action("hello", {"name": "potato"})
# ============================================================

const MOD_MAIN_PATH = "/root/ModLoader/FengLiu-FengAddMods"
const SESSION_NODE_NAME = "PotatoWorldSession"
const SESSION_SCRIPT = preload("res://mods-unpacked/FengLiu-FengAddMods/net/potato_world_session.gd")


# mod 主节点（ModLoader 把 mod_main.gd 挂在这里）；未就绪时返回 null
static func get_mod_main() -> Node:
	var main_loop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	return main_loop.root.get_node_or_null(MOD_MAIN_PATH)


# 取会话节点；不存在则创建并挂到 mod 主节点下（幂等）
static func get_session() -> Node:
	var mod_main := get_mod_main()
	if mod_main == null:
		return null

	var session := mod_main.get_node_or_null(SESSION_NODE_NAME)
	if session == null:
		session = SESSION_SCRIPT.new()
		session.name = SESSION_NODE_NAME
		mod_main.add_child(session)
		# 父节点正忙（ready 传播中）时 add_child 会被拒绝，延迟一帧再挂
		if session.get_parent() == null:
			mod_main.call_deferred("add_child", session)
	return session


static func is_available() -> bool:
	return get_mod_main() != null


# 按服务器地址建立会话（code = ip 或 ip:port)
# player_index：本地玩家槽位（-1 = 未知 / 无具体本地玩家，0..3 = Brotato 本地玩家），会随 join 的 player 一起发给 MC
static func connect_with_code(code: String, player_index: int = -1) -> bool:
	var session := get_session()
	if session == null:
		return false

	if not session.is_inside_tree():
		session.call_deferred("start", code, player_index)
		return true
	return session.start(code, player_index)


# 向会话下发动作；没有可用会话时返回 false
# player_index < 0 时用会话当前槽位，否则按本次动作指定的本地玩家发包
static func send_action(action: String, data: Dictionary = {}, player_index: int = -1) -> bool:
	var session := get_session()
	if session == null:
		return false
	return session.send_action(action, data, player_index)


# 设置/读取会话默认的本地玩家槽位
static func set_player_index(index: int) -> void:
	var session := get_session()
	if session == null:
		return
	session.set_player_index(index)


static func get_player_index() -> int:
	var session := get_session()
	if session == null:
		return -1
	return session.get_player_index()


static func disconnect_session() -> void:
	var session := get_session()
	if session == null:
		return
	session.stop("requested")


static func get_state() -> int:
	var session := get_session()
	if session == null:
		return -1
	return session.get_state()
