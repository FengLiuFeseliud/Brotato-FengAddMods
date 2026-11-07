extends "res://entities/gpe/acid_puddle/acid_puddle.gd"


var stat_fengliu_acid_puddle_size_hash: int = Keys.generate_hash("fengliu_acid_puddle_size")
var effect_fengliu_acid_puddle_reverse: int = Keys.generate_hash("fengliu_acid_puddle_reverse")

# 反转生效时：池内敌人（每 tick 结算一次）
var _fengliu_enemies: Array = []
var _fengliu_enemy_tick: float = 0.0


# 酸液池尺寸受次要属性影响
func init(size: Vector2 = Vector2(1, 1)) -> void:
	var size_multiplier: float = max(0.01, 1.0 + Utils.sum_all_player_stats(stat_fengliu_acid_puddle_size_hash) / 100.0)
	.init(size * size_multiplier)

	# 让 Area2D 也能检测敌人（玩家层 2 + 敌人层 4）
	collision_mask |= Utils.ENEMIES_BIT
	_fengliu_enemies.clear()
	_fengliu_enemy_tick = tick_interval


# 跟踪进入池子的敌人
func _on_body_entered(body) -> void:
	if body is Enemy and not _fengliu_enemies.has(body):
		_fengliu_enemies.push_back(body)

	._on_body_entered(body)


func _on_body_exited(body) -> void:
	if body is Enemy:
		_fengliu_enemies.erase(body)

	._on_body_exited(body)


# 每 tick_interval 对池内敌人结算一次「反转伤害」
func _physics_process(delta: float) -> void:
	if _is_dying or _fengliu_enemies.empty():
		return

	var state: Dictionary = fengliu_get_reverse_state()
	if not state.active:
		return

	_fengliu_enemy_tick -= delta
	if _fengliu_enemy_tick > 0.0:
		return

	_fengliu_enemy_tick = tick_interval
	fengliu_damage_enemies(int(state.damage), int(state.player_index))


func fengliu_get_reverse_state() -> Dictionary:
	var owner_index: int = - 1
	var damage: int = 0

	for i in RunData.get_player_count():
		var effects: Array = RunData.get_player_effect(effect_fengliu_acid_puddle_reverse, i)
		if effects.empty():
			continue

		if owner_index < 0:
			owner_index = i

		for effect in effects:
			if effect != null and effect.has_method("get_final_enemy_damage"):
				damage += int(effect.get_final_enemy_damage(i))

	return {
		"active": owner_index >= 0 and damage > 0,
		"damage": damage,
		"player_index": owner_index
	}


func fengliu_damage_enemies(base_damage: int, player_index: int) -> void:
	if player_index < 0 or base_damage <= 0:
		return

	for i in range(_fengliu_enemies.size() - 1, - 1, - 1):
		var enemy = _fengliu_enemies[i]
		if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die or enemy._is_charmed:
			_fengliu_enemies.remove(i)
			continue

		var args: TakeDamageArgs = TakeDamageArgs.new(player_index)
		args.armor_applied = true
		args.dodgeable = false
		args.is_burning = false

		var main = Utils.get_scene_node()
		if main != null and "_players" in main and player_index < main._players.size():
			args.from = main._players[player_index]

		var _dmg = enemy.take_damage(base_damage, args)


func _return_to_pool() -> void:
	_fengliu_enemies.clear()
	_fengliu_enemy_tick = 0.0
	._return_to_pool()

