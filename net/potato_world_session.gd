extends Node


# ============================================================
# 「土豆的世界」HTTP 会话
#   负责：按地址建立会话、长轮询事件、下发动作、断线退避
#   会话节点由 PotatoWorldNet 惰性创建并挂在 mod 主节点下，跨场景常驻
#   全部网络操作非阻塞：HTTPRequest + _process 驱动，不开线程
# ============================================================

const PotatoWorldApi = preload("res://mods-unpacked/FengLiu-FengAddMods/net/potato_world_api.gd")

const MOD_ID = "FengAddMods"
const LOG_NAME = "FengAddMods:PotatoWorld"

# join / action 请求超时（秒）
const JOIN_TIMEOUT = 10.0
const ACTION_TIMEOUT = 10.0
# 断线重试退避
const BACKOFF_MIN = 1.0
const BACKOFF_MAX = 30.0
# join 连续失败上限（超过判定为失败）
const MAX_JOIN_RETRIES = 5
# 轮询连续失败上限（超过判定为掉线）
const MAX_POLL_FAILURES = 5
# 本地玩家槽位上限（Brotato 最多 4 人同屏）
const MAX_LOCAL_PLAYER_INDEX = 3

enum State { IDLE, JOINING, READY, CLOSED, FAILED }

signal state_changed(state)
signal session_ready(info)
signal events_received(events)
signal action_result(ok, data)
signal session_closed(reason)
signal error_received(code, message)

var _state: int = State.IDLE
var _target := {}
var _token := ""
var _cursor := 0
var _expires_at_ms := 0

var _join_req: HTTPRequest
var _poll_req: HTTPRequest
var _action_req: HTTPRequest
var _leave_req: HTTPRequest

var _join_inflight := false
var _poll_inflight := false
var _action_inflight := false
var _leave_inflight := false

var _join_retries := 0
var _poll_failures := 0
var _backoff_seconds := BACKOFF_MIN
var _next_attempt_ms := 0

var _action_queue := []
var _action_expected_type := ""
var _long_poll_seconds := 0.0
var _poll_interval := 0.0

# 当前会话对应的本地玩家槽位（-1 = 未知 / 无具体本地玩家；每个 player 段都会带上）
var _player_index := -1


func _ready() -> void:
	_fengliu_create_requests()
	set_process(false)


func _exit_tree() -> void:
	stop("node_exit")


# 开始一个新会话：code 是 MC 服务器地址（ip / ip:port，默认端口见 potato_world_api.gd）
# player_index < 0 时沿用会话当前值；主菜单连接默认 0
func start(code: String, player_index: int = -1) -> bool:
	var parsed: Dictionary = PotatoWorldApi.parse_target(code)
	if not parsed.get("ok", false):
		_fengliu_emit_error(parsed.get("reason", "invalid_address"), "Invalid server address: " + code)
		_set_state(State.FAILED)
		return false

	# 重复连接时先收掉旧会话（leave 使用旧槽位）
	if _state == State.JOINING or _state == State.READY:
		stop("restart")

	# 新会话使用传入的本地玩家槽位（默认 -1 = 未知）
	set_player_index(player_index)

	_target = parsed
	_token = ""
	_cursor = 0
	_expires_at_ms = 0
	_join_retries = 0
	_poll_failures = 0
	_backoff_seconds = BACKOFF_MIN
	_next_attempt_ms = 0
	_action_queue.clear()
	_long_poll_seconds = PotatoWorldApi.LONG_POLL_SECONDS
	_poll_interval = 0.0 if _long_poll_seconds > 0.0 else PotatoWorldApi.SHORT_POLL_INTERVAL

	ModLoaderLog.info("Connecting to %s (player_index=%d)" % [_target.get("base_url", ""), _player_index], LOG_NAME)
	set_process(true)
	_begin_join()
	return true


# 关闭会话：尽力通知服务端，然后清理本地状态
func stop(reason: String = "closed") -> void:
	var was_active: bool = _state == State.JOINING or _state == State.READY
	if was_active:
		_send_leave()

	_token = ""
	_cursor = 0
	_expires_at_ms = 0
	_action_queue.clear()
	_action_expected_type = ""
	_join_inflight = false
	_poll_inflight = false
	_action_inflight = false
	_leave_inflight = false
	_join_retries = 0
	_poll_failures = 0
	_backoff_seconds = BACKOFF_MIN
	_next_attempt_ms = 0
	set_process(false)

	if was_active:
		_set_state(State.CLOSED)
		emit_signal("session_closed", reason)


# 下发一个动作；返回 false 表示当前没有可用会话
# player_index < 0 时使用会话当前槽位，否则按本次动作指定的本地玩家发包
func send_action(action: String, data: Dictionary = {}, player_index: int = -1) -> bool:
	if _state != State.READY:
		return false
	var resolved_index := _player_index
	if player_index >= 0:
		resolved_index = int(clamp(player_index, 0, MAX_LOCAL_PLAYER_INDEX))
	_action_queue.push_back({"action": action, "data": data, "player_index": resolved_index})
	return true


func get_state() -> int:
	return _state


func is_ready() -> bool:
	return _state == State.READY


func get_target() -> Dictionary:
	return _target


func get_token() -> String:
	return _token


# 兼容旧调用
func get_session_id() -> String:
	return get_token()


# 本地玩家槽位（-1 = 未知 / 无具体本地玩家，0..3 = Brotato 本地玩家），会写进每个 player 段
func set_player_index(index: int) -> void:
	_player_index = int(clamp(index, -1, MAX_LOCAL_PLAYER_INDEX))


func get_player_index() -> int:
	return _player_index


# 取平台用户 ID：Steam 版就是 SteamID（数字字符串），其它平台返回 "user"
func _fengliu_get_steam_id() -> String:
	var platform = get_node_or_null("/root/Platform")
	if platform == null:
		return ""
	return str(platform.get_user_id())


# 用户名：平台自带的优先，其次 GodotSteam 的 persona name，最后兜底 "user"
func _fengliu_get_steam_name() -> String:
	var platform = get_node_or_null("/root/Platform")
	if platform != null and platform.has_method("get_user_name"):
		var platform_name := str(platform.get_user_name())
		if platform_name != "":
			return platform_name

	if Engine.has_singleton("Steam"):
		var steam = Engine.get_singleton("Steam")
		if steam != null and steam.has_method("getPersonaName"):
			var persona := str(steam.getPersonaName())
			if persona != "":
				return persona

	return "user"


# 每包都带的 player 段
# player_index < 0 时用会话当前槽位；MC 侧按 (steam_id, player_index) 区分本地玩家
func _fengliu_get_player_info(player_index: int = -1) -> Dictionary:
	var resolved_index := _player_index
	if player_index >= 0:
		resolved_index = int(clamp(player_index, 0, MAX_LOCAL_PLAYER_INDEX))
	return {
		"steam_id": _fengliu_get_steam_id(),
		"steam_name": _fengliu_get_steam_name(),
		"player_index": resolved_index,
	}


func _process(_delta: float) -> void:
	var now := OS.get_ticks_msec()

	if _state == State.JOINING:
		if not _join_inflight and now >= _next_attempt_ms:
			_begin_join()
		return

	if _state != State.READY:
		return

	# 会话即将过期：提前重新 join，避免轮询被服务端拒绝
	if _expires_at_ms > 0 and now >= _expires_at_ms - 10000 and not _join_inflight:
		ModLoaderLog.info("Session is about to expire, rejoining.", LOG_NAME)
		_begin_join()
		return

	if _action_queue.size() > 0 and not _action_inflight:
		_fengliu_send_next_action()

	if not _poll_inflight and now >= _next_attempt_ms:
		_begin_poll()


func _begin_join() -> void:
	if _join_inflight:
		return
	_join_inflight = true
	_set_state(State.JOINING)

	var meta := {
		"target": "%s:%d" % [_target.get("host", ""), int(_target.get("port", 0))],
		"player": _fengliu_get_player_info(),
	}
	_join_req.timeout = JOIN_TIMEOUT
	var error := _join_req.request(
		_target.get("base_url", "") + PotatoWorldApi.PATH_JOIN,
		PotatoWorldApi.build_headers(),
		true,
		HTTPClient.METHOD_POST,
		PotatoWorldApi.encode_message(PotatoWorldApi.PATH_JOIN, {}, meta)
	)
	if error != OK:
		_join_inflight = false
		_fengliu_schedule_retry("join_request_failed", false)


func _on_join_completed(result: int, response_code: int, _headers: PoolStringArray, body: PoolByteArray) -> void:
	_join_inflight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_fengliu_schedule_retry("join_network_error", false)
		return

	var msg: Dictionary = PotatoWorldApi.parse_message(body)
	if bool(msg.get("parse_error", false)):
		# 严格模式：响应不是统一信封直接判失败，不重试
		var envelope_error: Dictionary = msg.get("error", {})
		_fengliu_emit_error(
			str(envelope_error.get("code", "invalid_envelope")),
			str(envelope_error.get("message", ""))
		)
		_set_state(State.FAILED)
		set_process(false)
		return

	var status_code := _fengliu_message_code(msg, response_code)
	# 429 / 5xx 属于临时故障，退避后重试
	if status_code == 429 or status_code >= 500:
		_fengliu_schedule_retry("join_http_%d" % status_code, false)
		return

	var data: Dictionary = msg.get("data", {})
	# 错误信封可能由传输层提前返回（type 仍是请求 path），错误分支不强制 session_join
	if not PotatoWorldApi.is_success(msg):
		# 其余 4xx / ok=false：地址或会话被服务端拒绝，属于永久失败
		_fengliu_emit_error(
			PotatoWorldApi.error_code(msg, "join_failed"),
			PotatoWorldApi.error_message(msg, "Join failed")
		)
		_set_state(State.FAILED)
		set_process(false)
		return

	# 成功响应 type 固定为 session_join（请求 path 只用于路由）
	if not _fengliu_matches_type(msg, PotatoWorldApi.TYPE_SESSION_JOIN):
		_fengliu_emit_error("type_mismatch", "Unexpected response type: " + str(msg.get("type", "")))
		_set_state(State.FAILED)
		set_process(false)
		return

	_join_retries = 0
	_poll_failures = 0
	_backoff_seconds = BACKOFF_MIN
	_next_attempt_ms = 0
	_token = str(data.get("token", ""))
	_cursor = int(data.get("cursor", _cursor))
	var expires_in := float(data.get("expires_in", 0.0))
	_expires_at_ms = 0
	if expires_in > 0.0:
		_expires_at_ms = OS.get_ticks_msec() + int(expires_in * 1000.0)
	_long_poll_seconds = float(data.get("long_poll_seconds", PotatoWorldApi.LONG_POLL_SECONDS))
	_poll_interval = 0.0 if _long_poll_seconds > 0.0 else PotatoWorldApi.SHORT_POLL_INTERVAL
	_set_state(State.READY)
	emit_signal("session_ready", {
		"host": _target.get("host", ""),
		"port": int(_target.get("port", 0)),
		"expires_in": expires_in,
	})
	ModLoaderLog.success("Potato World session ready (%s)" % _target.get("base_url", ""), LOG_NAME)


func _begin_poll() -> void:
	if _poll_inflight:
		return
	_poll_inflight = true

	var wait_seconds := int(_long_poll_seconds)
	var url := "%s%s?steam_id=%s&since=%d&wait=%d&player_index=%d" % [
		_target.get("base_url", ""),
		PotatoWorldApi.PATH_EVENTS,
		_fengliu_get_steam_id().http_escape(),
		_cursor,
		wait_seconds,
		_player_index,
	]
	_poll_req.timeout = max(_long_poll_seconds + 5.0, 10.0)
	var error := _poll_req.request(url, PotatoWorldApi.build_headers(), true, HTTPClient.METHOD_GET)
	if error != OK:
		_poll_inflight = false
		_fengliu_schedule_retry("poll_request_failed", true)


func _on_poll_completed(result: int, response_code: int, _headers: PoolStringArray, body: PoolByteArray) -> void:
	_poll_inflight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_fengliu_schedule_retry("poll_network_error", true)
		return

	var msg: Dictionary = PotatoWorldApi.parse_message(body)
	if bool(msg.get("parse_error", false)):
		var envelope_error: Dictionary = msg.get("error", {})
		_fengliu_emit_error(
			str(envelope_error.get("code", "invalid_envelope")),
			str(envelope_error.get("message", ""))
		)
		stop("invalid_envelope")
		return

	var status_code := _fengliu_message_code(msg, response_code)

	# 会话过期 / 鉴权失效：丢掉旧会话重新 join
	if status_code == 401 or status_code == 403 or status_code == 410:
		ModLoaderLog.warning("Session rejected (%d), rejoining." % status_code, LOG_NAME)
		_token = ""
		_cursor = 0
		_set_state(State.JOINING)
		_next_attempt_ms = 0
		return

	if status_code == 429 or status_code >= 500:
		_fengliu_schedule_retry("poll_http_%d" % status_code, true)
		return

	if not _fengliu_matches_type(msg, PotatoWorldApi.PATH_EVENTS):
		_fengliu_schedule_retry("poll_type_mismatch", true)
		return

	if not PotatoWorldApi.is_success(msg):
		# 业务错误：记录后继续按退避重试（连续失败会判掉线）
		_fengliu_emit_error(
			PotatoWorldApi.error_code(msg, "poll_failed"),
			PotatoWorldApi.error_message(msg, "")
		)
		_fengliu_schedule_retry("poll_business_error", true)
		return

	var data: Dictionary = msg.get("data", {})
	var events = data.get("events", [])
	if events is Array:
		# 旧版 MC 可能不带 player_index；统一补 -1，保证每条事件都有该字段
		for event in events:
			if event is Dictionary and not event.has("player_index"):
				event["player_index"] = -1
		if events.size() > 0:
			emit_signal("events_received", events)
	_cursor = int(data.get("cursor", _cursor))
	_poll_failures = 0
	_backoff_seconds = BACKOFF_MIN
	if _long_poll_seconds > 0.0:
		# 长轮询：立即发起下一次
		_next_attempt_ms = 0
	else:
		_next_attempt_ms = OS.get_ticks_msec() + int(_poll_interval * 1000.0)


func _fengliu_send_next_action() -> void:
	if _action_inflight or _action_queue.size() == 0:
		return

	var item = _action_queue.pop_front()
	_action_inflight = true
	# 业务参数放 data；player 每包都带；action 名字拼进 type
	var payload: Dictionary = item.get("data", {})
	var action_name := str(item.get("action", ""))
	var action_player_index := int(item.get("player_index", -1))
	_action_expected_type = PotatoWorldApi.PATH_ACTION + "/" + action_name.http_escape()
	var meta := {
		"player": _fengliu_get_player_info(action_player_index),
	}
	_action_req.timeout = ACTION_TIMEOUT
	var error := _action_req.request(
		_target.get("base_url", "") + _action_expected_type,
		PotatoWorldApi.build_headers(),
		true,
		HTTPClient.METHOD_POST,
		PotatoWorldApi.encode_message(_action_expected_type, payload, meta)
	)
	if error != OK:
		_action_inflight = false
		emit_signal("action_result", false, {"error": "request_failed"})


func _on_action_completed(result: int, response_code: int, _headers: PoolStringArray, body: PoolByteArray) -> void:
	_action_inflight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("action_result", false, {"error": "network_error"})
		return

	var msg: Dictionary = PotatoWorldApi.parse_message(body)
	if bool(msg.get("parse_error", false)):
		var envelope_error: Dictionary = msg.get("error", {})
		emit_signal("action_result", false, {
			"error": str(envelope_error.get("code", "invalid_envelope")),
			"message": str(envelope_error.get("message", "")),
		})
		return
	if not _fengliu_matches_type(msg, _action_expected_type):
		emit_signal("action_result", false, {"error": "type_mismatch"})
		return
	if not PotatoWorldApi.is_success(msg):
		emit_signal("action_result", false, {
			"error": PotatoWorldApi.error_code(msg, "action_failed"),
			"message": PotatoWorldApi.error_message(msg, ""),
		})
		return
	emit_signal("action_result", true, msg.get("data", {}))


func _send_leave() -> void:
	if _leave_inflight:
		return
	_leave_inflight = true
	var meta := {"player": _fengliu_get_player_info()}
	var error := _leave_req.request(
		_target.get("base_url", "") + PotatoWorldApi.PATH_LEAVE,
		PotatoWorldApi.build_headers(),
		true,
		HTTPClient.METHOD_POST,
		PotatoWorldApi.encode_message(PotatoWorldApi.PATH_LEAVE, {}, meta)
	)
	if error != OK:
		_leave_inflight = false


func _on_leave_completed(_result: int, _response_code: int, _headers: PoolStringArray, _body: PoolByteArray) -> void:
	_leave_inflight = false


func _fengliu_schedule_retry(reason: String, is_poll: bool) -> void:
	var delay := _backoff_seconds
	_next_attempt_ms = OS.get_ticks_msec() + int(delay * 1000.0)
	_backoff_seconds = min(_backoff_seconds * 2.0, BACKOFF_MAX)

	if is_poll:
		_poll_failures += 1
		ModLoaderLog.warning(
			"Poll failed (%s), retry %d/%d in %.1fs" % [reason, _poll_failures, MAX_POLL_FAILURES, delay],
			LOG_NAME
		)
		if _poll_failures >= MAX_POLL_FAILURES:
			ModLoaderLog.warning("Potato World connection lost.", LOG_NAME)
			stop("connection_lost")
		return

	_join_retries += 1
	ModLoaderLog.warning(
		"Join failed (%s), retry %d/%d in %.1fs" % [reason, _join_retries, MAX_JOIN_RETRIES, delay],
		LOG_NAME
	)
	if _join_retries >= MAX_JOIN_RETRIES:
		_fengliu_emit_error("connect_failed", "Unable to reach " + str(_target.get("base_url", "")))
		_set_state(State.FAILED)
		set_process(false)


func _fengliu_create_requests() -> void:
	_join_req = _fengliu_make_request("JoinRequest", "_on_join_completed")
	_poll_req = _fengliu_make_request("PollRequest", "_on_poll_completed")
	_action_req = _fengliu_make_request("ActionRequest", "_on_action_completed")
	_leave_req = _fengliu_make_request("LeaveRequest", "_on_leave_completed")


func _fengliu_make_request(node_name: String, callback: String) -> HTTPRequest:
	var request := HTTPRequest.new()
	request.name = node_name
	request.use_threads = false
	add_child(request)
	request.connect("request_completed", self, callback)
	return request


# 信封里的 code 与 HTTP 状态码不一致时以信封为准（并记一条 warning）
func _fengliu_message_code(msg: Dictionary, response_code: int) -> int:
	var status_code := int(msg.get("code", 0))
	if status_code > 0 and response_code > 0 and status_code != response_code:
		ModLoaderLog.warning(
			"Envelope code (%d) != HTTP status (%d), using envelope code." % [status_code, response_code],
			LOG_NAME
		)
	if status_code > 0:
		return status_code
	return response_code


# type 就是接口标识：events / action 与请求 path 一致；
# join / leave 响应分别是 session_join / session_leave（严格模式）
func _fengliu_matches_type(msg: Dictionary, expected_path: String) -> bool:
	return str(msg.get("type", "")) == expected_path


func _set_state(new_state: int) -> void:
	if _state == new_state:
		return
	_state = new_state
	emit_signal("state_changed", new_state)


func _fengliu_emit_error(code: String, message: String) -> void:
	ModLoaderLog.warning("Potato World error [%s] %s" % [code, message], LOG_NAME)
	emit_signal("error_received", code, message)

