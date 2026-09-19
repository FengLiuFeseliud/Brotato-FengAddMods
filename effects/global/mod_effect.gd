extends Effect


# ============================================================
# 效果基类：本 mod 效果通用基类（Effect 分支）
#   统一把子类自己的导出字段（自定义字段）写进存档，读档时按字段声明
#   类型还原，避免续档后自定义字段丢失。
# ------------------------------------------------------------
# 约定：
#   子类必须自带 get_id()（返回 fengliu_ 前缀的唯一 id），
#   否则不会注册进 ItemService.effects，读档无法匹配。
# ============================================================

const FENGLIU_CUSTOM_FIELDS_KEY = "fengliu_custom_fields"
const FENGLIU_PERSIST_VARS_KEY = "fengliu_persist_vars"


# 取实例相对其基类脚本新增的导出字段名（排除基类已持久化的字段）
static func fengliu_get_custom_property_names(instance) -> Array:
	var base_names := {}
	var script = instance.get_script()
	if script != null:
		var base_script = script.get_base_script()
		if base_script != null:
			var base_instance = base_script.new()
			for property_info in base_instance.get_property_list():
				if (property_info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
					base_names[property_info.name] = true

	var names := []
	for property_info in instance.get_property_list():
		# 只取脚本级导出字段：同时带 SCRIPT_VARIABLE 与 EDITOR 标记
		if (property_info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		if (property_info.usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		if base_names.has(property_info.name):
			continue
		names.push_back(property_info.name)

	return names


# 需要随存档持久化的非导出变量名
func fengliu_persist_var_names() -> Array:
	return []


# 还原后的归一化钩子（子类可覆写，例如把 JSON 回来的浮点转回 int）
func fengliu_on_persist_vars_restored() -> void:
	pass


# 取实例声明的持久化变量名（未覆写时为空）
static func fengliu_get_persist_var_names(instance) -> Array:
	if not instance.has_method("fengliu_persist_var_names"):
		return []

	var names = instance.fengliu_persist_var_names()
	if names is Array:
		return names

	return []


# 序列化白名单非导出变量：变量名 → 编码后的值（只取实例真实存在的字段）
static func serialize_persist_vars(instance) -> Dictionary:
	var persist_vars := {}
	var property_names := {}
	for property_info in instance.get_property_list():
		property_names[property_info.name] = true

	for var_name in fengliu_get_persist_var_names(instance):
		if not property_names.has(var_name):
			continue
		persist_vars[var_name] = fengliu_encode_value(instance.get(var_name))

	return persist_vars


# 还原白名单非导出变量：按声明类型强转写回，最后调用归一化钩子
static func deserialize_persist_vars(instance, persist_vars) -> void:
	if persist_vars == null or typeof(persist_vars) != TYPE_DICTIONARY:
		return

	var property_types := {}
	for property_info in instance.get_property_list():
		property_types[property_info.name] = property_info.type

	for var_name in persist_vars:
		if not property_types.has(var_name):
			continue
		instance.set(var_name, fengliu_decode_value(persist_vars[var_name], property_types[var_name]))

	if instance.has_method("fengliu_on_persist_vars_restored"):
		instance.fengliu_on_persist_vars_restored()
# 编码字段值：资源引用存路径，数组逐元素处理，其余（数值/文本/布尔）原样
static func fengliu_encode_value(value):
	if value == null:
		return null

	if value is Resource:
		return value.resource_path

	if value is Array:
		var encoded := []
		for element in value:
			encoded.push_back(fengliu_encode_value(element))
		return encoded

	return value


# 序列化自定义字段：字段名 → 编码后的值
static func serialize_custom_fields(instance) -> Dictionary:
	var custom_fields := {}
	for property_name in fengliu_get_custom_property_names(instance):
		custom_fields[property_name] = fengliu_encode_value(instance.get(property_name))

	return custom_fields


# 按属性声明类型强转还原值（存档走 JSON，数字回来是浮点，必须强转）
static func fengliu_decode_value(value, property_type: int):
	if value == null:
		return null

	match property_type:
		TYPE_INT:
			return int(value)
		TYPE_REAL:
			return float(value)
		TYPE_STRING:
			return String(value)
		TYPE_BOOL:
			return bool(value)
		TYPE_ARRAY:
			return value.duplicate() if value is Array else []
		TYPE_OBJECT:
			# 资源字段存的是路径，按路径还原；路径为空则保持为空
			if value is String and value != "" and ResourceLoader.exists(value):
				return load(value)
			return null

	return value


# 还原自定义字段：只写回这个实例真实拥有的字段
static func deserialize_custom_fields(instance, custom_fields) -> void:
	if custom_fields == null or typeof(custom_fields) != TYPE_DICTIONARY:
		return

	var property_types := {}
	for property_info in instance.get_property_list():
		if (property_info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		property_types[property_info.name] = property_info.type

	for property_name in custom_fields:
		if not property_types.has(property_name):
			continue
		instance.set(property_name, fengliu_decode_value(custom_fields[property_name], property_types[property_name]))


# 先存基类导出字段，再存白名单非导出变量
func serialize() -> Dictionary:
	var serialized = .serialize()
	serialized[FENGLIU_CUSTOM_FIELDS_KEY] = serialize_custom_fields(self)

	# 只有声明了白名单的脚本才写这一项，避免改动其他效果的存档格式
	var persist_vars = serialize_persist_vars(self)
	if persist_vars.size() > 0:
		serialized[FENGLIU_PERSIST_VARS_KEY] = persist_vars

	return serialized


# 先还原基类字段，再还原自定义字段与白名单非导出变量
func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	if serialized.has(FENGLIU_CUSTOM_FIELDS_KEY):
		deserialize_custom_fields(self, serialized[FENGLIU_CUSTOM_FIELDS_KEY])

	# 未声明白名单的存档没有这一项，直接跳过
	if not serialized.has(FENGLIU_PERSIST_VARS_KEY):
		return

	deserialize_persist_vars(self, serialized[FENGLIU_PERSIST_VARS_KEY])
