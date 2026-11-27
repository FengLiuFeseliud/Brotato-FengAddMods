extends Reference


# ============================================================
# 通用动作调度器
#   供远程武器、建造者炮塔、蓝鲸共用。
#   只管理动作实例、普通攻击计数、触发条件与激活动作生命周期；
#   不负责生成子弹、播放动画或处理投射物命中，宿主通过公开方法读取状态。
# ------------------------------------------------------------
# 宿主要求：
#   - 动作资源实现 fengliu_is_ranged_action() 与 fengliu_setup(host)
#   - 宿主在普通攻击后自行调用 register_normal_attack()
#   - 宿主在合适时机调用 check_triggers() / update(delta)
# ============================================================

const PROJECTILE_ACTION_SNAPSHOT_META := "fengliu_action_snapshot"

var _entries: Array = []
var _active_actions: Array = []
var _normal_attack_count: int = 0


# 清空旧状态并建立动作实例；trigger_count <= 0 的动作立即常驻激活
func setup(host, action_resources) -> void:
	reset()
	if action_resources == null or not (action_resources is Array):
		return

	for action_resource in action_resources:
		if action_resource == null or not is_instance_valid(action_resource):
			continue
		if not action_resource.has_method("fengliu_is_ranged_action"):
			continue

		# 每个宿主使用独立动作实例，避免共享计时与状态
		var action = action_resource.duplicate()
		if action == null:
			continue

		action.fengliu_setup(host)
		_entries.push_back({
			"action": action,
			"last_trigger_count": -1,
			"fired": false,
		})

	_start_always_active_actions()


func reset() -> void:
	for action in _active_actions:
		if action != null and is_instance_valid(action):
			action.fengliu_finish()

	_active_actions.clear()
	_entries.clear()
	_normal_attack_count = 0


func _start_always_active_actions() -> void:
	for entry in _entries:
		var action = entry["action"]
		if action == null or not is_instance_valid(action):
			continue
		if action.fengliu_get_trigger_count() > 0:
			continue
		if action in _active_actions:
			continue

		_active_actions.push_back(action)
		action.fengliu_start()


func register_normal_attack() -> void:
	_normal_attack_count += 1


func get_normal_attack_count() -> int:
	return _normal_attack_count


# 达到首次触发次数后，按 trigger_interval / repeat 激活动作
func check_triggers() -> void:
	if _normal_attack_count <= 0:
		return

	for entry in _entries:
		var action = entry["action"]
		if action == null or not is_instance_valid(action):
			continue

		if entry["fired"] and not action.fengliu_should_repeat():
			continue

		var first_trigger_count: int = action.fengliu_get_trigger_count()
		if first_trigger_count <= 0:
			continue
		if _normal_attack_count < first_trigger_count:
			continue

		var trigger_interval: int = action.fengliu_get_trigger_interval()
		if trigger_interval <= 0:
			trigger_interval = first_trigger_count

		if (_normal_attack_count - first_trigger_count) % trigger_interval != 0:
			continue
		if entry["last_trigger_count"] == _normal_attack_count:
			continue

		if not action.fengliu_can_start():
			continue

		entry["last_trigger_count"] = _normal_attack_count
		if not action.fengliu_should_repeat():
			entry["fired"] = true

		if not action in _active_actions:
			_active_actions.push_back(action)
		action.fengliu_start()


func get_takeover_actions() -> Array:
	var result: Array = []
	for action in _active_actions:
		if action == null or not is_instance_valid(action):
			continue
		if not action.has_method("fengliu_should_take_over_shoot"):
			continue
		if action.fengliu_should_take_over_shoot():
			result.push_back(action)
	return result


func get_takeover_action():
	for action in _active_actions:
		if action == null or not is_instance_valid(action):
			continue
		if not action.has_method("fengliu_should_take_over_shoot"):
			continue
		if action.fengliu_should_take_over_shoot():
			return action
	return null


# 接管动作完成：立即结束并移出激活列表
func finish_takeover(action) -> void:
	if action == null or not is_instance_valid(action):
		return

	action.fengliu_finish()
	_active_actions.erase(action)


func should_block_shoot() -> bool:
	for action in _active_actions:
		if action != null and is_instance_valid(action) and action.fengliu_should_block_shoot():
			return true
	return false


func should_count_attack() -> bool:
	for action in _active_actions:
		if action != null and is_instance_valid(action) and not action.fengliu_should_count_as_attack():
			return false
	return true


func get_animation_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for action in _active_actions:
		if action != null and is_instance_valid(action):
			multiplier *= max(0.01, action.fengliu_get_animation_speed_multiplier())
	return max(0.01, multiplier)


func modify_cooldown(base_cooldown: float) -> float:
	var cooldown: float = base_cooldown
	for action in _active_actions:
		if action != null and is_instance_valid(action):
			cooldown = action.fengliu_modify_cooldown(cooldown)
	return cooldown


func any_action_takes_over_physics() -> bool:
	for action in _active_actions:
		if action != null and is_instance_valid(action) and action.fengliu_should_take_over_physics():
			return true
	return false


func any_action_takes_over_process() -> bool:
	for action in _active_actions:
		if action != null and is_instance_valid(action) and action.fengliu_should_take_over_process():
			return true
	return false


# 宿主停止时清理触发动作；常驻动作默认保留
func stop_all(keep_always_active: bool = true) -> void:
	var remaining_actions: Array = []
	for action in _active_actions:
		if action == null or not is_instance_valid(action):
			continue

		if keep_always_active and action.fengliu_get_trigger_count() <= 0:
			remaining_actions.push_back(action)
			continue

		action.fengliu_finish()

	_active_actions = remaining_actions


# 投射物快照：动作可能在命中前结束，命中时仍要按发射时的动作转发
func store_actions_on_projectile(projectile, actions: Array) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	projectile.set_meta(PROJECTILE_ACTION_SNAPSHOT_META, actions.duplicate())


func get_actions_from_projectile(projectile) -> Array:
	if projectile == null or not is_instance_valid(projectile):
		return []
	if not projectile.has_meta(PROJECTILE_ACTION_SNAPSHOT_META):
		return []

	var actions = projectile.get_meta(PROJECTILE_ACTION_SNAPSHOT_META)
	return actions if actions is Array else []

func update(delta: float) -> void:
	for i in range(_active_actions.size() - 1, -1, -1):
		var action = _active_actions[i]
		if action == null or not is_instance_valid(action):
			_active_actions.remove(i)
			continue

		action.fengliu_update(delta)
		if action.fengliu_is_finished():
			action.fengliu_finish()
			_active_actions.remove(i)


func get_active_actions() -> Array:
	return _active_actions.duplicate()
