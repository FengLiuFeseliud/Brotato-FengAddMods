extends "res://mods-unpacked/FengLiu-FengAddMods/effects/global/effect_below_hp_base.gd"


# ============================================================
# 效果：低于生命阈值时回满生命与护盾
#   阈值 / 每波一次 / 文案全部由 .tres 配置，脚本不设默认值。
#   运行时槽位：fengliu_below_hp（由基类统一管理）
# ------------------------------------------------------------
# .tres 建议配置：
#   hp_threshold_pct   触发阈值（例如 50）
#   once_per_wave      true = 每波最多触发一次
#   custom_key         填 fengliu_below_hp
#   text_key           例如 EFFECT_FENGLIU_BELOW_HP_FULL_RESTORE
# ============================================================


# 触发后要消耗的道具 id（空 = 不消耗）
export(String) var owner_item_id := ""


static func get_id() -> String:
	return "fengliu_below_hp_full_restore"


# 低于阈值：回满生命与护盾（显式完整恢复）
func fengliu_below_hp_execute(player_index: int) -> void:
	var player = _fengliu_get_player(player_index)
	if player == null:
		return

	_fengliu_restore_health(player)
	_fengliu_restore_shield(player, player_index)
	_fengliu_consume_owner_item(player_index)


# 取当前玩家节点；非战斗场景 / 越界 / 已死亡都返回 null
func _fengliu_get_player(player_index: int):
	var main = Utils.get_scene_node()
	if main == null:
		return null

	var players = main.get("_players")
	if not (players is Array):
		return null
	if player_index < 0 or player_index >= players.size():
		return null

	var player = players[player_index]
	if player == null or not is_instance_valid(player):
		return null
	if player.dead or player.cleaning_up:
		return null

	return player


# 回满生命：不走治疗结算，因此不受 no_heal / torture 限制
func _fengliu_restore_health(player) -> void:
	var max_health: int = int(player.max_stats.health)
	var missing_health: int = max_health - int(player.current_stats.health)
	if missing_health <= 0:
		return

	player.current_stats.health = max_health
	player.emit_signal("health_updated", player, player.current_stats.health, player.max_stats.health)
	player.emit_signal("healed", missing_health, player.player_index)

	if player.hp_regen_sounds != null and player.hp_regen_sounds.size() > 0:
		SoundManager.play(Utils.get_rand_element(player.hp_regen_sounds), player.get_heal_db(), 0.1)


# 回满护盾：上限为 0 或已超上限时保持不动；不受护盾无法恢复限制
func _fengliu_restore_shield(player, player_index: int) -> void:
	var shield_cap: float = Utils.get_stat(player.fengliu_shield_hash, player_index)
	if shield_cap <= 0.0:
		return

	var shield_before: float = player.fengliu_shield
	if shield_before >= shield_cap:
		return

	player.fengliu_shield = shield_cap
	var gained: int = int(round(player.fengliu_shield)) - int(round(shield_before))
	if gained > 0:
		player.emit_signal("fengliu_shield_gained", gained, player_index)
	elif player.has_method("fengliu_request_shield_hud_refresh"):
		player.fengliu_request_shield_hud_refresh()

	if player.has_method("fengliu_sync_full_shield_stat_link"):
		player.fengliu_sync_full_shield_stat_link()


# 消耗触发本效果的道具：优先按效果实例精确匹配，避免多件同名时删错
func _fengliu_consume_owner_item(player_index: int) -> void:
	if owner_item_id == "":
		return

	var items = RunData.get_player_items(player_index)
	var owner_item = null

	# 先找「effects 里包含本实例」的道具
	for item in items:
		if item == null or (item.has_meta("fengliu_consume_pending") and item.get_meta("fengliu_consume_pending") == true):
			continue
		if item.effects != null and item.effects.has(self):
			owner_item = item
			break

	# 兜底：按道具 id 匹配（读档后实例可能不是同一个）
	if owner_item == null:
		for item in items:
			if item == null or (item.has_meta("fengliu_consume_pending") and item.get_meta("fengliu_consume_pending") == true):
				continue
			if item.my_id == owner_item_id:
				owner_item = item
				break

	if owner_item == null:
		return

	owner_item.set_meta("fengliu_consume_pending", true)
	call_deferred("_fengliu_remove_owner_item_deferred", player_index, owner_item)


# 延迟删除：避免在玩家效果槽遍历期间改动数组
func _fengliu_remove_owner_item_deferred(player_index: int, owner_item) -> void:
	if owner_item == null:
		return

	if owner_item.has_meta("fengliu_consume_pending") and owner_item.get_meta("fengliu_consume_pending") == true:
		owner_item.remove_meta("fengliu_consume_pending")

	if not RunData.get_player_items(player_index).has(owner_item):
		return

	var before_count: int = RunData.get_player_items(player_index).size()
	RunData.remove_item(owner_item, player_index)

	# 读档后 item.effects 与槽实例可能对不上：成功移除道具后显式清一次槽
	if RunData.get_player_items(player_index).size() < before_count:
		unapply(player_index)


func serialize() -> Dictionary:
	var serialized = .serialize()
	# owner_item_id 声明在本中间基类，mod_effect 不会自动收集，必须显式持久化
	serialized.owner_item_id = owner_item_id
	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)
	if serialized.has("owner_item_id"):
		owner_item_id = str(serialized.owner_item_id)
