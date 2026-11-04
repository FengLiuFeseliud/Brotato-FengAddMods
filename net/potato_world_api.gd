extends Reference


# ============================================================
# 「土豆的世界」HTTP 契约与连接地址解析
#   玩家输入的 code 就是 MC 服务器地址：
#     1.2.3.4            -> 端口用 DEFAULT_PORT
#     1.2.3.4:9090       -> 端口 9090
#     mc.example.com     -> 端口用 DEFAULT_PORT
#     [fe80::1]:8080     -> IPv6 + 端口
#   换服务端 / 端口 / 接口路径只需要改本文件
# ============================================================

const DEFAULT_PORT = 8080

# 内网先用 http；公网部署改成 true 并给服务器配受信任证书
const USE_SSL = false

const PATH_JOIN = "/api/potato-world/join"
const PATH_EVENTS = "/api/potato-world/events"
const PATH_ACTION = "/api/potato-world/action"
const PATH_LEAVE = "/api/potato-world/leave"

# 服务端 join / leave 响应信封的 type（与请求 path 不同）
const TYPE_SESSION_JOIN = "session_join"
const TYPE_SESSION_LEAVE = "session_leave"

# 长轮询等待秒数；MC 侧 HTTP 若是单线程实现，改成 0.0 退化为短轮询
const LONG_POLL_SECONDS = 25.0

# 短轮询间隔（LONG_POLL_SECONDS 为 0.0 时使用）
const SHORT_POLL_INTERVAL = 2.0

const MSG_OK = "ok"
const MSG_CODE = "code"
const MSG_TYPE = "type"
const MSG_ERROR = "error"
const MSG_DATA = "data"


# 解析玩家输入：返回 {ok, host, port, base_url, reason}
static func parse_target(code: String) -> Dictionary:
	var raw := code.strip_edges()
	if raw == "":
		return {"ok": false, "reason": "empty"}

	var host := raw
	var port := DEFAULT_PORT
	if raw.begins_with("["):
		# [IPv6] 或 [IPv6]:port
		var close_index := raw.find("]")
		if close_index == -1:
			return {"ok": false, "reason": "invalid_address"}
		host = raw.substr(1, close_index - 1)
		var rest := raw.substr(close_index + 1).strip_edges()
		if rest != "":
			if not rest.begins_with(":"):
				return {"ok": false, "reason": "invalid_address"}
			port = _fengliu_parse_port(rest.substr(1))
			if port <= 0:
				return {"ok": false, "reason": "invalid_port"}
	else:
		var first_colon := raw.find(":")
		var last_colon := raw.rfind(":")
		if first_colon != -1 and first_colon == last_colon:
			# 只有一个冒号：host:port
			host = raw.substr(0, first_colon)
			port = _fengliu_parse_port(raw.substr(first_colon + 1))
			if port <= 0:
				return {"ok": false, "reason": "invalid_port"}
		# 多个冒号视为裸 IPv6，使用默认端口

	host = host.strip_edges()
	if host == "":
		return {"ok": false, "reason": "invalid_address"}

	return {
		"ok": true,
		"host": host,
		"port": port,
		"base_url": "%s://%s:%d" % ["https" if USE_SSL else "http", _fengliu_wrap_host(host), port],
	}


# 端口只接受 1~65535 的十进制数字
static func _fengliu_parse_port(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed == "" or not trimmed.is_valid_integer():
		return -1
	var value := int(trimmed)
	if value < 1 or value > 65535:
		return -1
	return value


# IPv6 拼 URL 需要中括号
static func _fengliu_wrap_host(host: String) -> String:
	if host.find(":") != -1 and not host.begins_with("["):
		return "[" + host + "]"
	return host


# 统一请求头；token 只在会话建立后使用
static func build_headers(token: String = "") -> PoolStringArray:
	var headers := PoolStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	return headers


# 请求信封：ok=true / code=200 / type=接口 path / data=业务字典
# extra 里的键合并到顶层（target / steam_id / session / action 等元信息），
# 但不允许覆盖 ok / code / type / data
static func build_message(type_path: String, data: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var message := {
		MSG_OK: true,
		MSG_CODE: 200,
		MSG_TYPE: type_path,
		MSG_DATA: data,
	}
	for key in extra.keys():
		if key == MSG_OK or key == MSG_CODE or key == MSG_TYPE or key == MSG_DATA:
			continue
		message[key] = extra[key]
	return message


static func encode_message(type_path: String, data: Dictionary, extra: Dictionary = {}) -> String:
	return JSON.print(build_message(type_path, data, extra))


# 解 JSON 对象
static func parse_message(body: PoolByteArray) -> Dictionary:
	var result := {
		"ok": false,
		"code": 0,
		"type": "",
		"error": {},
		"data": {},
		"parse_error": false,
	}

	var text := body.get_string_from_utf8().strip_edges()
	if text == "":
		return _fengliu_invalid(result, "invalid_json", "empty response body")

	var parsed := JSON.parse(text)
	if parsed.error != OK or not (parsed.result is Dictionary):
		return _fengliu_invalid(result, "invalid_json", "response is not a JSON object")

	var body_dict: Dictionary = parsed.result
	if not (body_dict.has(MSG_OK) and body_dict.has(MSG_CODE) and body_dict.has(MSG_TYPE) and body_dict.has(MSG_DATA)):
		return _fengliu_invalid(result, "invalid_envelope", "missing ok/code/type/data")

	var raw_ok = body_dict.get(MSG_OK)
	var raw_code = body_dict.get(MSG_CODE)
	var raw_type = body_dict.get(MSG_TYPE)
	var raw_data = body_dict.get(MSG_DATA)

	if typeof(raw_ok) != TYPE_BOOL:
		return _fengliu_invalid(result, "invalid_envelope", "ok must be bool")
	var code_type := typeof(raw_code)
	if code_type != TYPE_INT and code_type != TYPE_REAL:
		return _fengliu_invalid(result, "invalid_envelope", "code must be a number")
	if typeof(raw_type) != TYPE_STRING or str(raw_type) == "":
		return _fengliu_invalid(result, "invalid_envelope", "type must be a non-empty string")
	if not (raw_data is Dictionary):
		return _fengliu_invalid(result, "invalid_envelope", "data must be a dictionary")

	var status_code := int(raw_code)
	if code_type == TYPE_REAL and float(raw_code) != float(status_code):
		return _fengliu_invalid(result, "invalid_envelope", "code must be an integer")
	if status_code < 100 or status_code > 599:
		return _fengliu_invalid(result, "invalid_envelope", "code out of range")

	result["ok"] = bool(raw_ok)
	result["code"] = status_code
	result["type"] = str(raw_type)

	if result["ok"]:
		result["data"] = raw_data
		return result

	# 失败响应：根层 error 必须存在且合法，data 必须为空
	if not (body_dict.get(MSG_ERROR) is Dictionary):
		return _fengliu_invalid(result, "invalid_envelope", "error must be a dictionary")
	var raw_error: Dictionary = body_dict.get(MSG_ERROR)
	var error_text := str(raw_error.get("code", ""))
	if error_text == "":
		return _fengliu_invalid(result, "invalid_envelope", "error.code is required")
	if typeof(raw_error.get("message", "")) != TYPE_STRING:
		return _fengliu_invalid(result, "invalid_envelope", "error.message must be a string")
	if not raw_data.empty():
		return _fengliu_invalid(result, "invalid_data", "error response must have an empty data")

	result["data"] = {}
	result["error"] = {"code": error_text, "message": str(raw_error.get("message", ""))}
	return result


# 构造解析失败的结果（ok=false / code=0 / type 空 / data 空）
static func _fengliu_invalid(result: Dictionary, code: String, message: String) -> Dictionary:
	result["ok"] = false
	result["code"] = 0
	result["type"] = ""
	result["data"] = {}
	result["error"] = {"code": code, "message": message}
	result["parse_error"] = true
	return result


static func is_success(msg: Dictionary) -> bool:
	if not bool(msg.get(MSG_OK, false)):
		return false
	var status_code := int(msg.get(MSG_CODE, 0))
	return status_code >= 200 and status_code < 300


static func error_code(msg: Dictionary, fallback: String = "") -> String:
	var error = msg.get(MSG_ERROR, {})
	if error is Dictionary:
		var code_text := str(error.get("code", ""))
		if code_text != "":
			return code_text
	return fallback


static func error_message(msg: Dictionary, fallback: String = "") -> String:
	var error = msg.get(MSG_ERROR, {})
	if error is Dictionary:
		var message := str(error.get("message", ""))
		if message != "":
			return message
	return fallback
