extends Pet

# 真空吸附判定的持续时间（帧）：关闭后重新计时，形成脉冲式接触伤害
const HITBOX_ACTIVE_FRAMES: = 15

# 宠物捡到消耗品后额外给玩家的金币（在 _fengliu_on_consumable_picked_up 中结算）
const CONSUMABLE_PICKUP_GOLD: = 3

export (Resource) var weapon_stats

onready var _hitbox: = $Hitbox as Hitbox

var _current_weapon_stats: = WeaponStats.new()
var _current_cooldown: float = 0
var _attack_frames_left: float = 0
var _is_attacking: bool = false
var _damage_tracking_key_hash: int = Keys.generate_hash("item_robot_vacuum")
var _fengliu_attracted_items: Array = []


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	# 先按玩家属性算出武器属性，随后关闭命中判定，只在吸附脉冲时开启
	_hitbox.from = self
	init_stats()
	_hitbox.disable()
	_fengliu_register_damage_tracking()


func should_data_be_reload() -> bool:
	return true


# 按玩家属性重算近战武器属性
func init_stats() -> void :
	# 宠物近战属性不吃攻速，按近战伤害等主要属性加成
	var args: = WeaponServiceInitStatsArgs.new()
	_current_weapon_stats = WeaponService.init_melee_pet_stats(weapon_stats, player_index, args)
	_current_weapon_stats.burning_data.from = self

	# 命中判定同步最新伤害与击退
	_hitbox.projectiles_on_hit = []
	_fengliu_apply_weapon_stats()

	_current_cooldown = _current_weapon_stats.cooldown


func update_data(effect: PetEffect) -> void :
	.update_data(effect)


func reload_data() -> void :
	init_stats()


func set_current_stats(stats: Array) -> void :
	# 复用同场景其它个体算好的属性，避免重复计算
	_current_weapon_stats = stats[0]
	_current_weapon_stats.burning_data.from = self
	_fengliu_apply_weapon_stats()


func get_stats() -> Array:
	return [_current_weapon_stats]


# 把当前武器属性写入命中判定
func _fengliu_apply_weapon_stats() -> void :
	var hitbox_args: = Hitbox.HitboxArgs.new().set_from_weapon_stats(_current_weapon_stats)

	_hitbox.effect_scale = _current_weapon_stats.effect_scale
	_hitbox.set_damage(_current_weapon_stats.damage, hitbox_args)
	_hitbox.speed_percent_modifier = _current_weapon_stats.speed_percent_modifier
	# 方向留空：由被击中方按「远离攻击者」自行推导击退方向
	_hitbox.set_knockback(Vector2.ZERO, _current_weapon_stats.knockback, _current_weapon_stats.knockback_piercing)
	_hitbox.from = self


# 本 mod 道具不在原版追踪表内，首次生成时登记，用于结算显示造成伤害
func _fengliu_register_damage_tracking() -> void :
	# 未指定玩家的实例（编辑器预览等）无需登记
	if player_index == - 1:
		return

	# 追踪表以道具 id 哈希为键，登记后 add_tracked_value 才会生效
	if not RunData.init_tracked_items.has(_damage_tracking_key_hash):
		RunData.init_tracked_items[_damage_tracking_key_hash] = 0

	if not RunData.tracked_item_effects[player_index].has(_damage_tracking_key_hash):
		RunData.tracked_item_effects[player_index][_damage_tracking_key_hash] = 0


func _physics_process(delta: float) -> void :
	._physics_process(delta)

	if _end_of_wave:
		return

	# 冷却递减
	if not _is_attacking:
		_current_cooldown = max(_current_cooldown - Utils.physics_one(delta), 0)

	# 冷却一到就开启真空判定：贴身的敌人不需要探测就会被打到
	if _current_cooldown <= 0 and not _is_attacking:
		attack()
	# 判定窗口结束：关闭判定并重新进入冷却
	elif _is_attacking:
		_attack_frames_left = max(_attack_frames_left - Utils.physics_one(delta), 0)
		if _attack_frames_left <= 0:
			stop_attack()


# 开启真空判定：宠物本体不做任何旋转或位移
func attack() -> void :
	# 判定窗口与冷却交替开关，形成脉冲式接触伤害
	_is_attacking = true
	_attack_frames_left = HITBOX_ACTIVE_FRAMES
	_hitbox.enable()


# 关闭真空判定并重新进入冷却
func stop_attack() -> void :
	# 清空忽略列表，下一次判定才能再次命中同一目标
	_hitbox.ignored_objects.clear()
	_hitbox.disable()
	_current_cooldown = _current_weapon_stats.cooldown
	_is_attacking = false


# 物品进入吸附范围：抢下吸引权，让它飞向宠物
func _on_ItemAttractArea_area_entered(item: Item) -> void :
	# 只处理材料与消耗品，其它物品（加成金币等）不碰
	if not (item is Gold or item is Consumable):
		return

	# 已被别人吸住的物品不抢，只有原吸引者已阵亡时才接管
	if item.attracted_by != null and not _fengliu_attractor_is_dead(item):
		return

	# 会伤害玩家的消耗品不代吸，留给玩家自己决定踩不踩
	if _fengliu_is_damaging_consumable(item):
		return

	item.attracted_by = self
	# 物品落地一段时间后物理会被关闭，这里重新打开才会真的被吸向宠物
	item.set_physics_process(true)
	if not _fengliu_attracted_items.has(item):
		_fengliu_attracted_items.push_back(item)


# 物品碰到宠物本体：直接结算给玩家
func _on_ItemPickUpArea_area_entered(area: Area2D) -> void :
	# 材料碰到宠物：收益直接记在玩家名下
	if area is Gold:
		var gold = area as Gold
		_fengliu_forget_attracted_item(gold)
		gold.pickup(player_index)
		return

	# 非消耗品的区域（敌人等）直接忽略
	if not (area is Consumable):
		return

	var consumable = area as Consumable
	# 已被结算过的消耗品不重复结算（同一物品进出范围可能触发两次）
	if consumable.already_picked_up:
		return

	# 会伤害玩家的消耗品不代捡，交给玩家自己踩
	if _fengliu_is_damaging_consumable(consumable):
		return

	_fengliu_forget_attracted_item(consumable)
	consumable.pickup(player_index)
	# 拾取后走回调，自己的逻辑写在回调里
	_fengliu_on_consumable_picked_up(consumable)


# 宠物捡到消耗品后的回调
func _fengliu_on_consumable_picked_up(_consumable: Consumable) -> void :
	RunData.add_gold(CONSUMABLE_PICKUP_GOLD, player_index)


# 判断物品的原吸引者是否已经阵亡
func _fengliu_attractor_is_dead(item: Item) -> bool:
	# 玩家等非战斗单位永不算阵亡，避免宠物从玩家手里抢物品
	if not (item.attracted_by is Unit):
		return false

	# 只剩下会阵亡的单位才需要判断存活
	return (item.attracted_by as Unit).dead


# 判断消耗品是否会伤害玩家（毒果等），这类消耗品不代吸不代捡
func _fengliu_is_damaging_consumable(item: Item) -> bool:
	# 数据未就绪的消耗品按安全处理，避免读取空数据
	if not (item is Consumable):
		return false

	var consumable = item as Consumable
	if consumable.consumable_data == null:
		return false

	# 借用原版判定，同时尊重 mod 对「波次结束不拾取」的扩展
	return consumable.has_damage_effect()


# 把物品从本宠物的吸附列表里移除
func _fengliu_forget_attracted_item(item: Item) -> void :
	# 已被捡走的物品可能不在列表里
	var index: = _fengliu_attracted_items.find(item)
	if index == - 1:
		return

	_fengliu_attracted_items.remove(index)


# 找最近的存活玩家，供阵亡后转移物品使用
func _fengliu_get_closest_player():
	var closest = null
	var min_distance_squared: float = Utils.LARGE_NUMBER

	for player in players_ref:
		# 阵亡或已释放的玩家不作为目标
		if not is_instance_valid(player) or player.dead:
			continue

		var dist_squared: = global_position.distance_squared_to(player.global_position)
		if dist_squared < min_distance_squared:
			min_distance_squared = dist_squared
			closest = player

	return closest


func _on_Hitbox_hit_something(thing_hit, damage_dealt) -> void :
	# 同一次判定不重复命中同一目标
	_hitbox.ignored_objects.push_back(thing_hit)

	RunData.manage_life_steal(_current_weapon_stats, player_index)

	if damage_dealt > 0:
		RunData.add_tracked_value(player_index, _damage_tracking_key_hash, damage_dealt)
