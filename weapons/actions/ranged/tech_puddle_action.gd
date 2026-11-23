extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/ranged/ranged_action.gd"


# ============================================================
# 通用形态泥潭 action：按 .tres 配置的形态/染色/泥潭参数生效
#   - 玩家/弹药恐龙由 custom shooting behavior 先选形态、染色；
#   - 建筑者炮台没有 custom shooting behavior，由本 action 兜底选形态、染色；
#   - 命中时按子弹 meta 的形态生成酸液/机械泥潭。
#   action_name 留空，不额外插入武器描述行。
# ============================================================

export(String) var projectile_form_meta
export(int) var form_mutant
export(int) var form_meca
export(int) var form_neutral
export(Dictionary) var form_effect_keys
export(Dictionary) var form_tints
export(PackedScene) var puddle_scene
export(float) var puddle_radius
export(Array) var puddle_radius_tier_multipliers
export(float) var puddle_lifetime
export(float) var puddle_tick_interval
export(int) var puddle_mode_acid
export(int) var puddle_mode_slow
export(float) var puddle_slow_percent
export(float) var puddle_slow_hold
export(float) var puddle_damage_percent

const PUDDLE_BEHAVIOR = preload("res://mods-unpacked/FengLiu-FengAddMods/weapons/behaviors/tech_puddle_behavior.gd")


# 子弹没有形态时兜底：随机可用形态 + 染色 + 写入 meta
func fengliu_on_projectile_shot(projectile) -> void:
	if not is_instance_valid(projectile):
		return
	# 武器 custom shooting behavior 已自行决定形态时保留；炮塔侧每次都重新抽取
	if fengliu_host_uses_custom_projectile_form() and projectile.has_meta(projectile_form_meta):
		return

	var host_player_index: int = fengliu_get_host_player_index()
	if host_player_index < 0:
		return

	var form: int = PUDDLE_BEHAVIOR.pick_form(host_player_index, self)
	projectile.set_meta(projectile_form_meta, form)
	PUDDLE_BEHAVIOR.apply_projectile_form(projectile, form, self)


# 命中：按形态生成泥潭
func fengliu_on_projectile_hit(thing_hit, damage_dealt, projectile) -> void:
	if not is_instance_valid(projectile) or not projectile.has_meta(projectile_form_meta):
		return

	var form: int = int(projectile.get_meta(projectile_form_meta))
	var data: Dictionary = PUDDLE_BEHAVIOR.build_puddle_data(
		form,
		thing_hit,
		damage_dealt,
		projectile,
		fengliu_get_host_effects(),
		fengliu_get_host_tier(),
		self
	)
	if data.empty():
		return

	# 延迟到下一帧再添加 Area2D，避免在 hit_something 物理回调里改物理状态
	call_deferred("_fengliu_spawn_puddle_deferred", data)


func _fengliu_spawn_puddle_deferred(data: Dictionary) -> void:
	PUDDLE_BEHAVIOR.spawn_puddle(data, fengliu_get_host_player_index(), self, _fengliu_weapon)
