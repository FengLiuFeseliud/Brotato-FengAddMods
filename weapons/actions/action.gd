extends Resource


# ============================================================
# 通用武器动作基类
#   动作资源本身是 .tres，脚本挂在资源上；武器场景通过 actions 数组直接引用动作。
#   子类按需实现生命周期与钩子，武器类只负责调度，不写任何具体玩法数值。
# ------------------------------------------------------------
# 可配置参数：
#   trigger_count            第几次攻击首次触发；<= 0 表示初始化即常驻激活
#   trigger_interval         首次触发后每隔多少次再次触发（repeat=true；常驻激活时无效）
#   repeat                   是否重复触发（false = 仅首次）
#   action_id                动作标识（调试/识别用）
#   action_name              动作翻译键
#   block_normal_shoot       激活时是否禁止普通攻击
#   count_as_normal_attack   激活时自身攻击是否计入触发次数
# ------------------------------------------------------------
# 可选钩子（由子类覆写）：
#   fengliu_should_force_shoot       激活时即使无目标/移动中也强制开火
#   fengliu_should_lock_rotation     激活时是否锁定武器朝向
#   fengliu_get_locked_rotation      锁定的武器朝向（弧度）
#   fengliu_on_hit                   近战武器本体命中时触发
#   fengliu_on_passive_after_shoot   未激活时每次普通攻击后触发
#   fengliu_on_passive_physics_process 未激活时每物理帧触发
# ============================================================

export(int) var trigger_count
export(int) var trigger_interval
export(bool) var repeat
export(String) var action_id
export(String) var action_name
export(bool) var block_normal_shoot
export(bool) var count_as_normal_attack

var _fengliu_weapon = null
var _fengliu_active := false


# 供武器类用鸭子类型识别“这是一个武器动作”
func fengliu_is_action() -> bool:
	return true


# 武器初始化时调用，把动作实例绑定到武器
func fengliu_setup(weapon) -> void:
	_fengliu_weapon = weapon
	_fengliu_active = false


func fengliu_get_trigger_count() -> int:
	return trigger_count


func fengliu_get_trigger_interval() -> int:
	if trigger_interval <= 0:
		return trigger_count

	return trigger_interval


func get_args(_player_index: int = -1) -> Array:
	return [str(trigger_count)]


func fengliu_should_repeat() -> bool:
	return repeat


# 默认同一个动作不允许在激活期间重复启动；子类可覆写
func fengliu_can_start() -> bool:
	return not _fengliu_active


func fengliu_start() -> void:
	_fengliu_active = true


func fengliu_update(_delta: float) -> void:
	pass


func fengliu_is_active() -> bool:
	return _fengliu_active


func fengliu_is_finished() -> bool:
	return false


func fengliu_finish() -> void:
	if not _fengliu_active:
		return

	_fengliu_active = false
	fengliu_on_finish()


func fengliu_on_finish() -> void:
	pass


# 以下钩子由武器类在对应时机调用，默认不改变武器行为
func fengliu_should_block_shoot() -> bool:
	if not _fengliu_active:
		return false

	return block_normal_shoot


func fengliu_should_count_as_attack() -> bool:
	if not _fengliu_active:
		return true
		
	return count_as_normal_attack


# 动作接管武器物理帧/空闲帧的钩子（旋转、下挥等需要跳过父类瞄准/开火）
func fengliu_should_take_over_physics() -> bool:
	return false


func fengliu_should_take_over_process() -> bool:
	return false


# 强制动作在无目标/移动中继续开火；默认关闭
func fengliu_should_force_shoot() -> bool:
	return false


# 动作是否需要固定武器朝向；默认关闭
func fengliu_should_lock_rotation() -> bool:
	return false


# 固定朝向（弧度）；仅在 fengliu_should_lock_rotation() 为 true 时使用
func fengliu_get_locked_rotation() -> float:
	return 0.0


# 目标切换时由武器类调用；默认不处理
func fengliu_sync_aim_target() -> void:
	pass


func fengliu_process(_delta: float) -> void:
	pass


func fengliu_get_attack_type_override() -> int:
	return -1


func fengliu_get_animation_speed_multiplier() -> float:
	return 1.0


func fengliu_modify_cooldown(base_cooldown: float) -> float:
	return base_cooldown


func fengliu_on_before_shoot() -> void:
	pass


func fengliu_on_after_shoot() -> void:
	pass


# 被动攻击后钩子：动作未被激活时也会在每次普通攻击后调用
func fengliu_on_passive_after_shoot() -> void:
	pass


# 被动物理帧钩子：动作未被激活时也会每物理帧调用
func fengliu_on_passive_physics_process(_delta: float) -> void:
	pass


# 武器属性重建后钩子：由近战武器在 init_stats 后调用
func fengliu_on_weapon_stats_initialized() -> void:
	pass


# 近战武器本体命中钩子；由近战武器类在 hitbox == 武器本体 hitbox 时调用
func fengliu_on_hit(_thing_hit, _damage_dealt: int) -> void:
	pass
