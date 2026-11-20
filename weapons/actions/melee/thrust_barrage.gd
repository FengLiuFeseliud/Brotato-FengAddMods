extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/melee/melee_action.gd"


# ============================================================
# 近战动作：连刺
#   触发后持续 duration 秒，以指定动画速度与冷却倍率连续攻击；
#   当 .tres 配置为动画 ×2、冷却 ×0.5 时，攻击频率 = 原攻速的 2 倍。
#   所有参数均由动作 .tres 提供，脚本内不写死次数、持续时间与倍率。
# ------------------------------------------------------------
# 可配置参数：
#   duration                     持续秒数
#   animation_speed_multiplier   动画速度倍率
#   cooldown_multiplier          冷却倍率
#   attack_type_override         -1 保持武器自身；0 戳刺；1 横扫
#   shorten_cooldown_on_start    触发瞬间是否压缩当前冷却
#   compensate_recoil_duration   是否补偿 recoil_duration 保证严格倍率
#   min_cooldown_ticks           冷却下限（帧）
#   block_normal_shoot / count_as_normal_attack 由通用动作基类提供
# ============================================================

export(float) var duration
export(float) var animation_speed_multiplier
export(float) var cooldown_multiplier
export(int) var attack_type_override
export(bool) var shorten_cooldown_on_start
export(bool) var compensate_recoil_duration
export(float) var min_cooldown_ticks

var _fengliu_time_left := 0.0


func get_args(_player_index: int = -1) -> Array:
	return [str(trigger_count), str(duration), str(animation_speed_multiplier)]


func fengliu_start() -> void:
	.fengliu_start()
	_fengliu_time_left = max(0.01, duration)
	if shorten_cooldown_on_start and _fengliu_weapon != null and _fengliu_weapon.has_method("fengliu_shorten_current_cooldown"):
		_fengliu_weapon.fengliu_shorten_current_cooldown()


func fengliu_update(delta: float) -> void:
	if not _fengliu_active:
		return

	_fengliu_time_left -= delta
	if _fengliu_time_left <= 0.0:
		fengliu_finish()


func fengliu_is_finished() -> bool:
	return _fengliu_time_left <= 0.0


func fengliu_can_start() -> bool:
	return not _fengliu_active


func fengliu_get_attack_type_override() -> int:
	if not _fengliu_active:
		return -1

	if attack_type_override < -1 or attack_type_override > 1:
		return -1

	return attack_type_override


func fengliu_get_animation_speed_multiplier() -> float:
	if not _fengliu_active:
		return 1.0
		
	return max(0.01, animation_speed_multiplier)


func fengliu_modify_cooldown(base_cooldown: float) -> float:
	if not _fengliu_active:
		return base_cooldown

	var animation_multiplier: float = max(0.01, animation_speed_multiplier)
	var cooldown_scale: float = max(0.0, cooldown_multiplier)
	var modified_cooldown: float = base_cooldown * cooldown_scale

	# 动画加速不会缩短 recoil_duration，按公式扣掉这部分，保证总间隔等于设定倍率
	if compensate_recoil_duration:
		var recoil_ticks: float = 0.0
		if _fengliu_weapon != null and _fengliu_weapon.current_stats != null:
			recoil_ticks = _fengliu_weapon.current_stats.recoil_duration * 60.0
		modified_cooldown -= recoil_ticks * (1.0 - 1.0 / animation_multiplier)

	return max(max(1.0, min_cooldown_ticks), modified_cooldown)


func fengliu_on_finish() -> void:
	_fengliu_time_left = 0.0
