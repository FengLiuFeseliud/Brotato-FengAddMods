extends "res://mods-unpacked/FengLiu-FengAddMods/weapons/actions/melee/melee_action.gd"


# ============================================================
# 近战动作：命中进化
#   常驻生效；近战本体命中敌人时，按命中者的进化正负把它转化为
#   异变怪（进化 < 0）或机械怪（进化 > 0）；进化为 0 时不转化。
#   转化复用原版 EvolutionSceneEffectBehavior._evolution_enemy，
#   贴图、描边、粒子、生命/伤害/速度加成与死亡掉落均与原版一致。
#   已在异变/机械状态的敌人、被魅惑敌人与掉落外星人不会被转化。
# ------------------------------------------------------------
# 说明：
#   本动作不读取 effects 数值，三条武器效果仅用于面板说明；
#   路线只由命中者当前的 stat_evolution 正负决定。
# ============================================================


const EVOLUTION_PENDING_META := "fengliu_evolution_on_hit_pending"
const FORM_NONE := -1
const FORM_MUTANT := 0
const FORM_MECA := 1

var _fengliu_evolution_behavior = null
var _fengliu_warned_missing_behavior := false


func fengliu_on_hit(thing_hit, _damage_dealt: int) -> void:
	if not _fengliu_active:
		return

	if not (thing_hit is Enemy):
		return

	if not _fengliu_can_convert(thing_hit):
		return

	var player_index: int = _fengliu_get_player_index()
	if player_index < 0:
		return

	var evolution: float = Utils.get_stat(Keys.stat_evolution_hash, player_index)
	var form: int = _fengliu_get_form(evolution)
	if form == FORM_NONE:
		return

	var is_meca: bool = form == FORM_MECA
	var magnitude: float = abs(evolution)
	thing_hit.set_meta(EVOLUTION_PENDING_META, true)
	call_deferred("_fengliu_convert_deferred", thing_hit, is_meca, magnitude)


func _fengliu_get_player_index() -> int:
	if _fengliu_weapon == null or not is_instance_valid(_fengliu_weapon):
		return -1

	var value = _fengliu_weapon.get("player_index")
	if value == null:
		return -1

	return int(value)


func _fengliu_get_form(evolution: float) -> int:
	if evolution < 0.0:
		return FORM_MUTANT

	if evolution > 0.0:
		return FORM_MECA

	return FORM_NONE


func _fengliu_can_convert(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Enemy):
		return false

	if enemy.dead or enemy._pending_die:
		return false

	if enemy._is_meca or enemy._is_mutant:
		return false

	if enemy._is_charmed:
		return false

	if enemy.is_loot:
		return false

	if enemy.has_meta(EVOLUTION_PENDING_META):
		return false

	return true


func _fengliu_convert_deferred(enemy, is_meca: bool, magnitude: float) -> void:
	if not is_instance_valid(enemy):
		return

	enemy.remove_meta(EVOLUTION_PENDING_META)
	if not _fengliu_can_convert(enemy):
		return

	var behavior = _fengliu_get_evolution_behavior()
	if behavior == null:
		if not _fengliu_warned_missing_behavior:
			_fengliu_warned_missing_behavior = true
			push_warning("evolution_on_hit: EvolutionSceneEffectBehavior not found, skip enemy evolution.")
		return

	behavior._evolution_enemy(enemy, is_meca, magnitude)


func _fengliu_get_evolution_behavior():
	if _fengliu_evolution_behavior != null and is_instance_valid(_fengliu_evolution_behavior):
		return _fengliu_evolution_behavior

	var scene = Utils.get_scene_node()
	if scene == null:
		return null

	var container = scene.get_node_or_null("EffectBehaviors")
	if container == null:
		return null

	for child in container.get_children():
		if child.has_method("_evolution_enemy"):
			_fengliu_evolution_behavior = child
			return child

	return null
