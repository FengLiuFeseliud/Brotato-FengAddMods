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
	.init_stats(at_wave_begin)
	init_current_stats = current_stats.duplicate()

func reset() -> void:
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
	
	if effects.count(ROCKET_EFFECT) > 0:
		effects.remove(effects.find(ROCKET_EFFECT))


func bullet(current_stats) -> void:
	current_stats.projectile_scene = init_current_stats.projectile_scene


func obliterator_bullet(current_stats) -> void:
	current_stats.projectile_scene = OBLITERATR_BULLET
	current_stats.piercing += 99
	current_stats.piercing_dmg_reduction = 0


func rocket_projectile(current_stats) -> void:
	current_stats.projectile_scene = ROCKET_PROJECTILE
	effects.append(ROCKET_EFFECT)
	
	
func medicel_bullet(current_stats) -> void:
	current_stats.projectile_scene = MEDICEL_BULLET
	current_stats.lifesteal = 0.5 + 0.05 * tier
	

func slingshot_projectile(current_stats) -> void:
	current_stats.projectile_scene = SLINGSHOT_PROJECTILE
	current_stats.bounce += tier + 1
	current_stats.piercing_dmg_reduction = 0.5
	current_stats.bounce_dmg_reduction = 0
	

func bolt_projectile(current_stats) -> void:
	current_stats.projectile_scene = BOLT_PROJECTILE
	current_stats.piercing += tier + 1
	current_stats.piercing_dmg_reduction = 0


func switch_bullet() -> void:
	if _nb_shots_taken != 0 and _nb_shots_taken % shots_per_switch:
		return
	
	reset()
	var random_index = randi() % 6
	var nb_projectiles = current_stats.nb_projectiles + random_index
	current_stats.nb_projectiles = nb_projectiles
	current_stats.projectile_spread = current_stats.projectile_spread + 0.08 * nb_projectiles
	current_stats.cooldown = current_stats.cooldown + random_index * 9
	current_stats.damage /= nb_projectiles
	
	call(BULLET_SCENES.pick_random(), current_stats)
	
func shoot() -> void:
	switch_bullet()
	.shoot()
