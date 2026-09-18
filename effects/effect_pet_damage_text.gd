class_name PetDamageText
extends PetEffect


# ============================================================
# 效果：宠物伤害说明（通用）
#   任何宠物道具都可复用：只要填「宠物场景」与「武器属性」，
#   道具说明就会按玩家属性显示「伤害（缩放属性）」，与原版宠物一致。
# ------------------------------------------------------------
# 效果值：
#   weapon_stats  宠物武器属性（与宠物场景引用同一份 .tres）
# ============================================================


export (Resource) var weapon_stats


static func get_id() -> String:
	# 唯一 id：区别于原版 pet，便于日后按 id 注册为存档还原原型
	return "fengliu_pet_damage_text"


func get_args(player_index: int) -> Array:
	# 未配置武器属性时退回基类参数，避免读取空资源
	if weapon_stats == null:
		return .get_args(player_index)

	# 与宠物自身算法一致，保证说明数值与实战伤害相同
	var args: = WeaponServiceInitStatsArgs.new()
	var current_weapon_stats = _fengliu_init_pet_stats(weapon_stats, player_index, args)
	var scaling_stats_text = WeaponService.get_scaling_stats_icon_text(current_weapon_stats.scaling_stats)

	# [0] 伤害数值、[1] 缩放属性图标文本
	return [str(current_weapon_stats.damage), scaling_stats_text]


# 近战宠物走近战口径、远程宠物走远程口径
func _fengliu_init_pet_stats(from_stats, player_index: int, args) -> WeaponStats:
	# 远程宠物（如猫特林机枪）用远程武器属性算法
	if from_stats is RangedWeaponStats:
		return WeaponService.init_ranged_pet_stats(from_stats, player_index, false, args)

	# 其余（近战宠物）按近战武器属性算法
	return WeaponService.init_melee_pet_stats(from_stats, player_index, args)


func serialize() -> Dictionary:
	var serialized = .serialize()

	# 未配置武器属性时只存基类字段，还原后由 get_args 走兜底
	if weapon_stats == null:
		return serialized

	# 武器属性是资源引用，须随效果一起存档（并记下类型供还原）
	serialized.weapon_stats = weapon_stats.serialize()
	serialized.weapon_stats_is_ranged = (weapon_stats is RangedWeaponStats)

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void :
	.deserialize_and_merge(serialized)

	# 存档里没有武器属性（未配置）时保持为空
	if not serialized.has("weapon_stats"):
		return

	# 按存档记录的类型重建，远程宠物才能还原成远程属性
	var stats = RangedWeaponStats.new() if serialized.get("weapon_stats_is_ranged", false) else MeleeWeaponStats.new()
	stats.deserialize_and_merge(serialized.weapon_stats)
	weapon_stats = stats
