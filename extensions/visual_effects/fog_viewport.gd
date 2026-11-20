extends "res://visual_effects/fog_viewport.gd"


# ============================================================
# 迷雾视口扩展：本 mod 的「迷雾波概率」效果
#   每波初始化时按「每个玩家各自」的效果概率判定（多玩家不合并，单玩家多件相加），
#   命中者直接结算自己的永久属性扣除；任一玩家命中即本波迷雾。
#   必须在父类 _initialize() 之前把 main._is_fog_wave 置为 true，
#   否则父类会释放迷雾视口，无法补救。
# ============================================================

const FogWaveChanceScript = preload("res://mods-unpacked/FengLiu-FengAddMods/effects/effect_fog_wave_chance.gd")
const FENGLIU_FORCED_FOG_META := "fengliu_forced_fog_wave"

var fengliu_fog_wave_chance_hash = Keys.generate_hash("fengliu_fog_wave_chance")
var _fengliu_fog_roll_done := false


func _initialize():
	fengliu_try_force_fog_wave()
	._initialize()


# 每波只判定一次
func fengliu_try_force_fog_wave() -> void:
	if _fengliu_fog_roll_done:
		return
	_fengliu_fog_roll_done = true

	if main == null or not is_instance_valid(main) or main._is_fog_wave:
		return

	var fog_triggered := false
	for player_index in range(RunData.get_player_count()):
		var entries = RunData.get_player_effect(fengliu_fog_wave_chance_hash, player_index)
		if not (entries is Array):
			continue

		# 只累加该玩家自己的多件效果概率
		var chance := 0
		for entry in entries:
			if entry is Array and entry.size() >= 1:
				chance += int(entry[0])
				
		chance = min(chance, 100)
		if chance <= 0:
			continue

		if not Utils.get_chance_success(chance / 100.0):
			continue

		# 命中即扣该玩家自己的属性（只扣触发者）
		fog_triggered = true
		for entry in entries:
			if entry is Array and entry.size() >= 2:
				FogWaveChanceScript.fengliu_apply_stat_deductions(entry[1], player_index)

	if not fog_triggered:
		return

	# 任一玩家命中即本波迷雾（父类 _initialize 会据此保留迷雾视口）
	main._is_fog_wave = true
	main.set_meta(FENGLIU_FORCED_FOG_META, true)
