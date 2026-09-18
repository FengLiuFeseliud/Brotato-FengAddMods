extends TargetBehavior

# 消耗品与材料优先的选目标行为：先主动跑去捡消耗品，再捡材料，都没有就跟随玩家待命
# 原版 closest_material_target_behavior 断连时不检查状态，这里统一加保护

signal target_found()
signal target_player()

# 消耗品是否优先于材料；改为 false 则退回「先材料后消耗品」的原顺序
const PICK_CONSUMABLE_FIRST: = true
# 复扫消耗品的间隔（秒）
const SCAN_INTERVAL: = 0.3
# 追同一个消耗品超过该秒数还没靠近就放弃，避免卡在拿不到的位置
const GIVE_UP_SECONDS: = 3.0
# 判定「确实靠近了」的距离阈值（像素）
const GIVE_UP_PROGRESS_DISTANCE: = 8.0

var _main = null
var _entity_spawner = null
var _fengliu_scan_timer: float = 0.0
var _fengliu_given_up_consumables: Array = []
var _fengliu_chase_target = null
var _fengliu_chase_time: float = 0.0
var _fengliu_chase_distance: float = 0.0


func init(parent: Node) -> Node:
	.init(parent)

	# 共用同场景其它个体取好的引用，避免重复查找
	if _main == null or _entity_spawner == null:
		_entity_spawner = parent._entity_spawner_ref
		_main = parent._entity_spawner_ref._main
		# 新材料落地时立刻重新选目标，避免宠物追着已被捡走的位置
		_main.connect("gold_spawned", self, "_fengliu_on_gold_spawned")

	return self


# 目标为空时由 Pet 调用：按常量优先级取最近的消耗品或材料，其次跟随玩家
func update_target() -> void :
	_fengliu_clear_current_target()

	# 先消耗品后材料，先后顺序由 PICK_CONSUMABLE_FIRST 决定
	var first_item = _fengliu_get_closest_consumable() if PICK_CONSUMABLE_FIRST else _fengliu_get_closest_gold()
	var second_item = _fengliu_get_closest_gold() if PICK_CONSUMABLE_FIRST else _fengliu_get_closest_consumable()

	for item in [first_item, second_item]:
		if item == null:
			continue

		_parent.current_target = item
		item.connect("picked_up", self, "_fengliu_on_item_picked_up")
		emit_signal("target_found", self)
		return

	# 场上没有可捡的物品：跟着玩家走，贴身距离交给 MovementBehavior
	if _parent.player_index < 0 or _parent.player_index >= _parent.players_ref.size():
		emit_signal("target_found", self)
		return

	_parent.current_target = _parent.players_ref[_parent.player_index]
	emit_signal("target_player", self)


# 断开旧目标的信号，避免物品被捡走后残留连接
func _fengliu_clear_current_target() -> void :
	var old_target = _parent.current_target
	_parent.current_target = null

	# 只有物品需要断连，玩家没有接过这个信号
	if not is_instance_valid(old_target) or not (old_target is Item):
		return

	if old_target.is_connected("picked_up", self, "_fengliu_on_item_picked_up"):
		old_target.disconnect("picked_up", self, "_fengliu_on_item_picked_up")


# 每帧检查追物是否卡住，并按固定间隔复扫消耗品
func _physics_process(delta: float) -> void :
	# 未初始化、已阵亡或波次结束时不再参与选目标
	if _parent == null or _main == null:
		return

	if _parent.dead or _parent._end_of_wave:
		return

	_fengliu_check_consumable_chase(delta)

	_fengliu_scan_timer += delta
	if _fengliu_scan_timer < SCAN_INTERVAL:
		return

	_fengliu_scan_timer = 0.0
	_fengliu_rescan_consumable()


# 追消耗品时长时间没有靠近就放弃，避免宠物卡在拿不到的位置
func _fengliu_check_consumable_chase(delta: float) -> void :
	var target = _parent.current_target
	# 不在追消耗品（跟随玩家或追材料）时清空计时
	if not is_instance_valid(target) or not (target is Consumable):
		_fengliu_reset_chase_progress()
		return

	var distance: = global_position.distance_to(target.global_position)
	# 目标换了：重新开始计时
	if target != _fengliu_chase_target:
		_fengliu_chase_target = target
		_fengliu_chase_time = 0.0
		_fengliu_chase_distance = distance
		return

	# 有实质靠近：刷新最佳距离并重新计时
	if distance < _fengliu_chase_distance - GIVE_UP_PROGRESS_DISTANCE:
		_fengliu_chase_distance = distance
		_fengliu_chase_time = 0.0
		return

	_fengliu_chase_time += delta
	if _fengliu_chase_time >= GIVE_UP_SECONDS:
		_fengliu_give_up_consumable(target)


# 清空追物计时，换目标或不再追消耗品时调用
func _fengliu_reset_chase_progress() -> void :
	# 换目标或放弃时清空计时与最佳距离，避免新目标继承旧进度
	_fengliu_chase_target = null
	_fengliu_chase_time = 0.0
	_fengliu_chase_distance = 0.0


# 放弃某个消耗品并清空当前目标，让 Pet 下一帧重选
func _fengliu_give_up_consumable(consumable) -> void :
	# 同一物品只记录一次，避免名单膨胀
	if not _fengliu_given_up_consumables.has(consumable):
		_fengliu_given_up_consumables.push_back(consumable)

	_fengliu_reset_chase_progress()
	_fengliu_clear_current_target()


# 复扫消耗品：当前目标失效或场上有可捡的消耗品时让出目标，交给 Pet 重选
func _fengliu_rescan_consumable() -> void :
	# 还在追的那个仍然有效就不换，避免来回横跳
	if _parent.current_target is Consumable:
		if _fengliu_is_consumable_available(_parent.current_target):
			return

		_fengliu_clear_current_target()
		return

	# 有可捡的消耗品：材料目标或玩家目标都让位
	if _fengliu_get_closest_consumable() != null:
		_fengliu_clear_current_target()


# 清掉已消失或已被捡走的放弃记录，避免名单无限增长
func _fengliu_prune_given_up_consumables() -> void :
	# 名单通常很短，遍历副本以便安全删除
	for consumable in _fengliu_given_up_consumables.duplicate():
		if _fengliu_is_consumable_available(consumable):
			continue

		_fengliu_given_up_consumables.erase(consumable)


# 判断消耗品当前是否仍可代捡
func _fengliu_is_consumable_available(consumable) -> bool:
	# 已被回收或已被捡走的实例直接排除
	if not is_instance_valid(consumable) or consumable.already_picked_up:
		return false

	# 场上列表里没有的（已重新入池）不算
	if not _main._consumables.has(consumable):
		return false

	# 数据未就绪时保守处理，避免读取空数据
	if consumable.consumable_data == null:
		return false

	# 会伤害玩家的消耗品留给玩家自己踩（含 mod 的波次结束不拾取效果）
	return not consumable.has_damage_effect()


# 取场上最近的、还没被捡走且可以代捡的消耗品
func _fengliu_get_closest_consumable():
	_fengliu_prune_given_up_consumables()

	var closest = null
	var min_distance_squared: float = Utils.LARGE_NUMBER

	for consumable in _main._consumables:
		# 已放弃过的消耗品本轮不再考虑
		if _fengliu_given_up_consumables.has(consumable):
			continue

		if not _fengliu_is_consumable_available(consumable):
			continue

		var dist_squared: = global_position.distance_squared_to(consumable.global_position)
		if dist_squared < min_distance_squared:
			min_distance_squared = dist_squared
			closest = consumable

	return closest


# 取场上最近的、还没被捡走的材料
func _fengliu_get_closest_gold():
	var closest = null
	var min_distance_squared: float = Utils.LARGE_NUMBER

	for gold in _main._active_golds:
		# 已被捡走或已释放的材料不作为目标
		if not is_instance_valid(gold) or gold.already_picked_up:
			continue

		var dist_squared: = global_position.distance_squared_to(gold.global_position)
		if dist_squared < min_distance_squared:
			min_distance_squared = dist_squared
			closest = gold

	return closest


# 目标物品（材料或消耗品）被捡走：清空目标，下一帧重新选
func _fengliu_on_item_picked_up(item: Node, _player_index: int) -> void :
	# 先断连，避免同一物品重复触发
	if item.is_connected("picked_up", self, "_fengliu_on_item_picked_up"):
		item.disconnect("picked_up", self, "_fengliu_on_item_picked_up")

	_fengliu_reset_chase_progress()
	_parent.current_target = null


# 场上掉出新材料：重新选目标
func _fengliu_on_gold_spawned() -> void :
	_fengliu_clear_current_target()
