class_name SixSidedGunWeapon
extends RangedWeapon


var shots_per_switch: int = 10
var init_current_stats
var init_effects: Array
var init_piercing: int
var init_lifesteal: int
var init_bounce: int


const OBLITERATR_BULLET = preload("res://projectiles/obliterator/obliterator_bullet.tscn")
const ROCKET_PROJECTILE = preload("res://projectiles/rocket/rocket_projectile.tscn")
const ROCKET_EFFECT = preload("res://weapons/ranged/rocket_launcher/rocket_launcher_effect.tres")
const MEDICEL_BULLET = preload("res://projectiles/bullet_medical/bullet_medical.tscn")
const SLINGSHOT_PROJECTILE = preload("res://projectiles/bullet_slingshot/slingshot_projectile.tscn")
const BOLT_PROJECTILE = preload("res://projectiles/bolt/bolt_projectile.tscn")


const BULLET_SCENES = [
	"bullet",
	"obliterator_bullet",
	"rocket_projectile",
	"medicel_bullet",
	"slingshot_projectile",
	"bolt_projectile"
]


func init_stats(at_wave_begin: bool = true) -> void:
	# 备份初始属性，切换弹种后据此还原
	.init_stats(at_wave_begin)
	init_current_stats = current_stats.duplicate()

func reset() -> void:
	# 还原弹丸场景与各项弹道属性
	current_stats.projectile_scene = init_current_stats.projectile_scene
	current_stats.piercing = init_current_stats.piercing
	current_stats.piercing_dmg_reduction = init_current_stats.piercing_dmg_reduction
	current_stats.lifesteal = init_current_stats.lifesteal
	current_stats.bounce = init_current_stats.bounce
	current_stats.bounce_dmg_reduction = init_current_stats.bounce_dmg_reduction
	
	current_stats.nb_projectiles = init_current_stats.nb_projectiles
	current_stats.projectile_spread = init_current_stats.projectile_spread
	current_stats.cooldown = init_current_stats.cooldown
	current_stats.damage = init_current_stats.damage
	
	# 移除上一轮附加的火箭爆炸效果
	if effects.count(ROCKET_EFFECT) > 0:
		effects.remove(effects.find(ROCKET_EFFECT))


func bullet(current_stats) -> void:
	# 普通子弹：用回初始弹丸场景
	current_stats.projectile_scene = init_current_stats.projectile_scene


func obliterator_bullet(current_stats) -> void:
	# 湮灭弹：+99 穿透且穿透不衰减
	current_stats.projectile_scene = OBLITERATR_BULLET
	current_stats.piercing += 99
	current_stats.piercing_dmg_reduction = 0


func rocket_projectile(current_stats) -> void:
	# 火箭弹：额外附加火箭爆炸效果
	current_stats.projectile_scene = ROCKET_PROJECTILE
	effects.append(ROCKET_EFFECT)
	
	
func medicel_bullet(current_stats) -> void:
	# 医疗弹：按品阶给予吸血
	current_stats.projectile_scene = MEDICEL_BULLET
	current_stats.lifesteal = 0.5 + 0.05 * tier
	

func slingshot_projectile(current_stats) -> void:
	# 弹弓弹：按品阶增加弹跳，且弹跳不衰减
	current_stats.projectile_scene = SLINGSHOT_PROJECTILE
	current_stats.bounce += tier + 1
	current_stats.piercing_dmg_reduction = 0.5
	current_stats.bounce_dmg_reduction = 0
	

func bolt_projectile(current_stats) -> void:
	# 弩箭：按品阶增加穿透，且穿透不衰减
	current_stats.projectile_scene = BOLT_PROJECTILE
	current_stats.piercing += tier + 1
	current_stats.piercing_dmg_reduction = 0


func switch_bullet() -> void:
	# 未到换弹间隔时保持当前弹种
	if _nb_shots_taken != 0 and _nb_shots_taken % shots_per_switch:
		return
	
	# 先还原再按随机索引重设弹丸数、散射、冷却与单发伤害
	reset()
	var random_index = randi() % 6
	var nb_projectiles = current_stats.nb_projectiles + random_index
	current_stats.nb_projectiles = nb_projectiles
	current_stats.projectile_spread = current_stats.projectile_spread + 0.08 * nb_projectiles
	current_stats.cooldown = current_stats.cooldown + random_index * 9
	current_stats.damage /= nb_projectiles
	
	# 随机挑选一种弹种对应的初始化方法
	call(BULLET_SCENES.pick_random(), current_stats)
	
func shoot() -> void:
	# 开火前先判定是否切换弹种
	switch_bullet()
	.shoot()
