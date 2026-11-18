class_name BlackHoleEffect
extends StructureEffect


# ============================================================
# 效果：黑洞发生器（构筑物）
#   生成「黑洞」构筑物：
#     - 判定半径 = stats.max_range（300 + 构筑物射程）× (1 + 1% × 本黑洞击杀数)
#     - 每 tick（stats.cooldown 30 帧，受建筑攻速影响）对半径内敌人造成
#       面板伤害（5 + 50/75/100/150% 工程学，按档位）并朝中心吸引面板击退的距离
#     - 造成（10 + 50/75/100/125% 工程学）次伤害后核心淡出并自毁
#   运行期 effect id：fengliu_black_hole
# ============================================================

const BLACK_HOLE_SCRIPT = preload("res://mods-unpacked/FengLiu-FengAddMods/content_data/entities/structures/black_hole/black_hole.gd")

export (float) var default_pull_distance: float = 25.0
export (int) var close_after_attacks_base: int = 10
export (float) var engineering_attack_rate: float = 0.5

var _init_stats_args_black_hole: = WeaponServiceInitStatsArgs.new()


static func get_id() -> String:
	return "fengliu_black_hole"


# 本效果生成的构筑物把伤害记在哪个道具的追踪键上
func fengliu_get_damage_tracking_key() -> String:
	return BLACK_HOLE_SCRIPT.DAMAGE_TRACKING_KEY


# 黑洞判定半径 = init 后的构筑物面板 max_range（300 + 构筑物射程）
func fengliu_get_radius(player_index: int) -> int:
	var base_radius: float = float(stats.max_range) if stats != null else 100.0
	if player_index < 0:
		return int(base_radius)

	# 取 init 后的构筑物面板（含构筑物射程加成），与游戏内实际半径保持一致
	if stats != null:
		_init_stats_args_black_hole.effects = effects
		var init_stats = WeaponService.init_structure_stats(stats, player_index, _init_stats_args_black_hole)
		if init_stats != null:
			base_radius = float(init_stats.max_range)

	return int(base_radius)


# 消失前的伤害次数 = 10 + 50/75/100/125% 工程学（按档位）
func fengliu_get_attacks_before_close(player_index: int) -> int:
	var engineering: float = Utils.get_stat(Keys.stat_engineering_hash, player_index) if player_index >= 0 else 0.0
	return int(max(1, close_after_attacks_base + int(engineering * engineering_attack_rate)))


func get_args(player_index: int) -> Array:
	var damage: int = int(stats.damage) if stats != null else 0
	var scaling_text: String = "-"

	if player_index >= 0 and stats != null:
		_init_stats_args_black_hole.effects = effects
		scaling_text = WeaponService.get_scaling_stats_icon_text(stats.scaling_stats)
		var init_stats = WeaponService.init_structure_stats(stats, player_index, _init_stats_args_black_hole)
		if init_stats != null:
			damage = init_stats.damage
			scaling_text = WeaponService.get_scaling_stats_icon_text(init_stats.scaling_stats)

	return [
		str(damage),
		str(fengliu_get_radius(player_index)),
		str(fengliu_get_attacks_before_close(player_index)),
		"",
		scaling_text,
		Utils.get_scaling_stat_icon_text(Keys.stat_engineering_hash, engineering_attack_rate)
	]


func serialize() -> Dictionary:
	var serialized = .serialize()
	serialized.default_pull_distance = default_pull_distance
	serialized.close_after_attacks_base = close_after_attacks_base
	serialized.engineering_attack_rate = engineering_attack_rate
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	default_pull_distance = serialized.default_pull_distance
	close_after_attacks_base = serialized.close_after_attacks_base
	engineering_attack_rate = serialized.engineering_attack_rate
