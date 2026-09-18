class_name ModChanceStatDamageEffect
extends ChanceStatDamageEffect


# ============================================================
# 效果基类：本 mod 效果通用基类（ChanceStatDamageEffect 分支）
#   基类已自持久化 chance / tracking_text，这里只补自定义字段持久化。
# ------------------------------------------------------------
# 约定：
#   子类必须自带 get_id()（返回 fengliu_ 前缀的唯一 id）。
# ============================================================



# 需要随存档持久化的非导出变量名（子类覆写；默认无）
func fengliu_persist_var_names() -> Array:
	return []


# 先存基类字段，再存自定义导出字段与白名单非导出变量
func serialize() -> Dictionary:
	var serialized = .serialize()
	serialized[ModEffect.FENGLIU_CUSTOM_FIELDS_KEY] = ModEffect.serialize_custom_fields(self)

	# 只有声明了白名单的脚本才写这一项
	var persist_vars = ModEffect.serialize_persist_vars(self)
	if persist_vars.size() > 0:
		serialized[ModEffect.FENGLIU_PERSIST_VARS_KEY] = persist_vars

	return serialized


# 先还原基类字段（含 tracking_key 重建），再还原自定义字段与白名单非导出变量
func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	if serialized.has(ModEffect.FENGLIU_CUSTOM_FIELDS_KEY):
		ModEffect.deserialize_custom_fields(self, serialized[ModEffect.FENGLIU_CUSTOM_FIELDS_KEY])

	# 未声明白名单的存档没有这一项，直接跳过
	if not serialized.has(ModEffect.FENGLIU_PERSIST_VARS_KEY):
		return

	ModEffect.deserialize_persist_vars(self, serialized[ModEffect.FENGLIU_PERSIST_VARS_KEY])
