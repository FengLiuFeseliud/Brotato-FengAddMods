extends Boss

# 火车站

export (PackedScene) var train_car_scene
export (int) var train_car_number = 5
export (float) var train_car_spacing = 224.0
export (float) var train_wrap_padding = 112.0
export (float) var train_speed = 420.0
export (float) var train_spawn_delay = 0.4
export (float) var train_stop_duration = 1.0
export (float) var train_fade_duration = 0.6
export (PackedScene) var rails_scene

# 列车阶段：0 行驶 / 1 缓停 / 2 停运（等车厢全灭）/ 3 淡出
const PHASE_RUN = 0
const PHASE_STOP = 1
const PHASE_PARK = 2
const PHASE_FADE = 3

var _fengliu_cars: Array = []
var _fengliu_slots: Dictionary = {}
var _fengliu_cut_slot: int = 9999
var _fengliu_path: Array = []
var _fengliu_segment_lengths: Array = []
var _fengliu_total_length: float = 0.0
var _fengliu_train_t: float = 0.0
var _fengliu_phase: int = PHASE_RUN
var _fengliu_stop_from: float = 0.0
var _fengliu_stop_distance: float = 0.0
var _fengliu_phase_time: float = 0.0
var _fengliu_rails = null
var _fengliu_released: bool = false


func _ready() -> void :
	._ready()


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, players_ref, entity_spawner_ref)
	# 放在 init 里而不是 _ready：对象池复用时 _ready 不会再跑，必须重新排定生成
	_fengliu_reset_train()
	_fengliu_spawn_rails()
	var spawn_timer: SceneTreeTimer = get_tree().create_timer(train_spawn_delay)
	var _error_spawn = spawn_timer.connect("timeout", self, "_fengliu_spawn_train")
	var rails_timer: SceneTreeTimer = get_tree().create_timer(train_spawn_delay + 0.2)
	var _error_rails = rails_timer.connect("timeout", self, "_fengliu_rebuild_rails")


func _fengliu_reset_train() -> void :
	# 新生成或池复用都要回到初始态，避免带上一局的阶段 / 里程 / 淡出透明度
	_fengliu_phase = PHASE_RUN
	_fengliu_phase_time = 0.0
	_fengliu_stop_from = 0.0
	_fengliu_stop_distance = 0.0
	_fengliu_train_t = 0.0
	_fengliu_total_length = 0.0
	_fengliu_cars = []
	_fengliu_slots = {}
	_fengliu_cut_slot = 9999
	_fengliu_path = []
	_fengliu_segment_lengths = []
	_fengliu_free_rails()
	_fengliu_released = false


func _fengliu_spawn_rails() -> void :
	# 铁轨挂到 Main 下、Entities 之前：盖住地砖（TileMap，z=0）又压在单位之下；
	# 若挂在 Boss 子节点（z_index -1）会被地砖完全遮住 —— 这就是之前铁轨看不见的原因
	_fengliu_free_rails()
	if rails_scene == null or _entity_spawner_ref == null:
		return

	var main = _entity_spawner_ref._main
	if main == null:
		return

	var rails = rails_scene.instance()
	main.add_child(rails)
	var container = main._entities_container
	if container != null and container.get_parent() == main:
		main.move_child(rails, container.get_index())

	_fengliu_rails = rails
	_fengliu_rebuild_rails()
	# 兜底：玩家一直不打车厢时，本波结束统一收轨（避免铁轨被带进下一波）
	if main.has_signal("end_of_the_wave") and not main.is_connected("end_of_the_wave", self, "_fengliu_on_wave_end"):
		var _error_wave_end = main.connect("end_of_the_wave", self, "_fengliu_on_wave_end")


func _fengliu_rebuild_rails() -> void :
	# 按当前场地矩形重新铺段（场地矩形晚就绪时补一次）
	if _fengliu_rails != null and is_instance_valid(_fengliu_rails) and _fengliu_rails.has_method("_fengliu_build"):
		_fengliu_rails._fengliu_build(global_position)


func _fengliu_free_rails() -> void :
	# 释放铁轨节点（换波清场 / 淡出结束 / 池复用重置时调用）
	if _fengliu_rails != null and is_instance_valid(_fengliu_rails):
		_fengliu_rails.queue_free()
	_fengliu_rails = null


func _fengliu_spawn_train() -> void :
	if not is_instance_valid(self) or dead:
		return
		
	if train_car_scene == null or train_car_number <= 0 or _entity_spawner_ref == null:
		return
		
	if _fengliu_cars.size() > 0:
		return

	_fengliu_build_path()
	# 每节独立走生成链路，且需要拿到实例引用 -> 直接用 entity_spawner.spawn_entity
	for _index in train_car_number:
		var args = EntitySpawner.SpawnEntityArgs.new(global_position, EntityType.ENEMY)
		var car = _entity_spawner_ref.spawn_entity(train_car_scene, args, null, self)
		if car != null:
			# 记下出生槽位：后续只按槽位摆放，打掉一节不会把后面的车拽过来
			_fengliu_slots[car.get_instance_id()] = _index
			_fengliu_cars.push_back(car)
	_fengliu_place_cars()


func _physics_process(delta: float) -> void :
	# 先跑基类（本体速度为 0 不会位移，只处理动画与物理）；随后按阶段推进列车
	._physics_process(delta)

	_fengliu_drop_dead_cars()
	if _fengliu_phase == PHASE_RUN:
		if _fengliu_cars.size() == 0 or _fengliu_total_length <= 0.0:
			return
		_fengliu_train_t = fmod(_fengliu_train_t + train_speed * delta, _fengliu_total_length)
		_fengliu_place_cars()
	elif _fengliu_phase == PHASE_STOP:
		_fengliu_update_stop(delta)
	elif _fengliu_phase == PHASE_PARK:
		_fengliu_update_park(delta)
	elif _fengliu_phase == PHASE_FADE:
		_fengliu_update_fade(delta)


func _fengliu_place_cars() -> void :
	# 车头按里程推进，每节按「出生时分配的槽位」挂在自己该在的位置；
	# 拆成单节函数调用 —— 某一节出问题不会中断其余车厢的摆放
	for car in _fengliu_cars:
		_fengliu_place_one(car)


func _fengliu_place_one(car) -> void :
	# 摆放单节车厢；槽位大于「断点」的车厢原地停住（被击杀那节后面的全部停车）
	if not is_instance_valid(car) or car.dead:
		return
	var car_id: int = car.get_instance_id()
	var slot: int = int(_fengliu_slots[car_id]) if _fengliu_slots.has(car_id) else 0
	if slot > _fengliu_cut_slot:
		return
	var distance: float = fmod(_fengliu_train_t - slot * train_car_spacing + _fengliu_total_length * 1000.0, _fengliu_total_length)
	car.global_position = _fengliu_path_point(distance)
	# 纵向段把贴图转 -90°（素材是「从左到右」的侧视图），横向段恢复 0°
	if car.sprite != null:
		car.sprite.rotation = - PI * 0.5 if _fengliu_path_is_vertical(distance) else 0.0


func _fengliu_drop_dead_cars() -> void :
	# 被击杀的车厢从列表剔除，并把「断点」前移到它（它后面的车厢全部停住）
	for i in range(_fengliu_cars.size() - 1, - 1, - 1):
		var car = _fengliu_cars[i]
		if not is_instance_valid(car) or car.dead:
			if is_instance_valid(car):
				var car_id: int = car.get_instance_id()
				if _fengliu_slots.has(car_id):
					_fengliu_cut_slot = min(_fengliu_cut_slot, int(_fengliu_slots[car_id]))
					_fengliu_slots.erase(car_id)
			_fengliu_cars.remove(i)


func _fengliu_build_path() -> void :
	# 十字闭环（单向、不回头）：右行到右边缘外→左边缘外重入→交叉点转向→上行到上边缘外→
	# 下边缘外重入→交叉点转向→右行……出屏点外扩 train_wrap_padding，保证整节车厢离场后才瞬移
	var zone_rect: Rect2 = ZoneService.get_current_zone_rect()
	var center: Vector2 = global_position
	var left_x: float = zone_rect.position.x - train_wrap_padding
	var right_x: float = zone_rect.end.x + train_wrap_padding
	var top_y: float = zone_rect.position.y - train_wrap_padding
	var bottom_y: float = zone_rect.end.y + train_wrap_padding
	_fengliu_path = [
		Vector2( left_x, center.y ),
		center,
		Vector2( center.x, top_y ),
		Vector2( center.x, bottom_y ),
		center,
		Vector2( right_x, center.y ),
		Vector2( left_x, center.y ),
	]
	# 第 3 段（上端出口→下端入口）与第 6 段（右端出口→左端入口）是瞬移段：
	# 参数长度记 0，取点时自动跳过，车厢表现为「穿出屏幕后从对面出来」
	var jump_segments: Array = [3, 6]
	_fengliu_segment_lengths = []
	_fengliu_total_length = 0.0
	for i in range(1, _fengliu_path.size()):
		var segment_length: float = 0.0
		if not jump_segments.has(i):
			segment_length = (_fengliu_path[i] - _fengliu_path[i - 1]).length()
		_fengliu_segment_lengths.push_back(segment_length)
		_fengliu_total_length += segment_length
	_fengliu_train_t = 0.0


func _fengliu_path_point(distance: float) -> Vector2 :
	# 折线取点：零长度段（瞬移段）自动跳过
	var remaining: float = distance
	for i in _fengliu_segment_lengths.size():
		var segment_length: float = _fengliu_segment_lengths[i]
		if segment_length > 0.0 and remaining <= segment_length:
			return _fengliu_path[i].linear_interpolate(_fengliu_path[i + 1], remaining / segment_length)
		remaining -= segment_length
	return _fengliu_path[0]


func _fengliu_path_is_vertical(distance: float) -> bool :
	# 判断该里程落在横向还是纵向轨道上（瞬移段长度为 0 会被跳过）
	var remaining: float = distance
	for i in _fengliu_segment_lengths.size():
		var segment_length: float = _fengliu_segment_lengths[i]
		if segment_length > 0.0 and remaining <= segment_length:
			var segment_delta: Vector2 = _fengliu_path[i + 1] - _fengliu_path[i]
			return abs(segment_delta.y) > abs(segment_delta.x)
		remaining -= segment_length
	return false


func _fengliu_begin_stop() -> void :
	# 缓停起点：滑行距离 = 车速 × 时长 ÷ 2（二次缓出的平均速度约为一半）
	_fengliu_phase = PHASE_STOP
	_fengliu_phase_time = 0.0
	_fengliu_stop_from = _fengliu_train_t
	_fengliu_stop_distance = train_speed * train_stop_duration * 0.5


func _fengliu_update_stop(delta: float) -> void :
	# 二次缓出：起速=当前车速、末速=0，滑行到停住（不倒车、不瞬移）
	_fengliu_phase_time += delta
	var progress: float = 1.0
	if train_stop_duration > 0.0:
		progress = min(_fengliu_phase_time / train_stop_duration, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	_fengliu_train_t = fmod(_fengliu_stop_from + _fengliu_stop_distance * eased, _fengliu_total_length)
	_fengliu_place_cars()
	if progress >= 1.0:
		_fengliu_phase = PHASE_PARK
		# 滑停时车厢已被打光，就直接收轨
		if _fengliu_cars.size() == 0:
			_fengliu_begin_fade()


func _fengliu_update_park(_delta: float) -> void :
	# 停运：铁轨保留、车厢仍可击杀；只有「站台 + 全部车厢」都死了才收轨
	if _fengliu_cars.size() == 0:
		_fengliu_begin_fade()


func _fengliu_on_wave_end() -> void :
	# 换波兜底：车厢没打完也要收轨，停运 / 淡出中的本体一并释放
	if not dead or _fengliu_phase == PHASE_RUN:
		return
	_fengliu_phase = PHASE_RUN
	var cleanup_args = Entity.DieArgs.new()
	cleanup_args.cleaning_up = true
	_fengliu_clear_cars(cleanup_args)
	_fengliu_free_rails()
	_fengliu_release()


func _fengliu_begin_fade() -> void :
	# 淡出：残留车厢静默清场（cleaning_up 不结算掉落），铁轨开始渐隐
	_fengliu_phase = PHASE_FADE
	_fengliu_phase_time = 0.0
	var cleanup_args = Entity.DieArgs.new()
	cleanup_args.cleaning_up = true
	_fengliu_clear_cars(cleanup_args)


func _fengliu_update_fade(delta: float) -> void :
	# 铁轨 alpha 渐隐，结束后释放本体（铁轨随节点离开场景）
	_fengliu_phase_time += delta
	var alpha: float = 1.0
	if train_fade_duration > 0.0:
		alpha = max(1.0 - _fengliu_phase_time / train_fade_duration, 0.0)
	if _fengliu_rails != null and is_instance_valid(_fengliu_rails):
		_fengliu_rails._fengliu_set_alpha(alpha)
	if _fengliu_phase_time >= train_fade_duration:
		_fengliu_free_rails()
		_fengliu_release()


func _fengliu_release() -> void :
	# 释放本体（断信号 + 回对象池）：淡出结束与换波兜底都走这里，重复调用被忽略
	if _fengliu_released:
		return
	_fengliu_released = true
	.death_animation_finished()


func _fengliu_clear_cars(args) -> void :
	# 清掉还活着的车厢（已死的跳过），随后清空列表
	for car in _fengliu_cars:
		if is_instance_valid(car) and not car.dead:
			car.die(args)
	_fengliu_cars = []


func die(args: = Utils.default_die_args) -> void :
	# 本体阵亡：先缓停再进入停运（车厢全灭才收轨）；波次清场（cleaning_up）时直接走原逻辑
	if not args.cleaning_up and _fengliu_cars.size() > 0 and _fengliu_total_length > 0.0:
		_fengliu_begin_stop()
	else:
		_fengliu_clear_cars(args)
		_fengliu_free_rails()
	# 尸体不再射击（缓停 / 停运期间只保留铁轨与列车）
	if _attack_behavior is ShootingAttackBehavior:
		_attack_behavior.max_range = 0
	.die(args)


func death_animation_finished() -> void :
	# 已释放（换波兜底先收尾过）就直接跳过，避免对象池被重复归还
	if _fengliu_released:
		return
	# 死亡动画结束：列车还在缓停/停运/淡出就先不释放节点（基类这里会回对象池），
	# 只收起本体贴图，把铁轨与停住的列车留在场上
	if _fengliu_phase == PHASE_STOP or _fengliu_phase == PHASE_PARK or _fengliu_phase == PHASE_FADE:
		var spr = get_node_or_null("Animation/Sprite")
		if spr != null:
			spr.hide()
		return
	.death_animation_finished()
