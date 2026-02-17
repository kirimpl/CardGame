extends Node

const SAVE_PATH: String = "user://run_save.json"
const SIM_CSV_PATH: String = "user://sim_report.csv"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func save_run() -> bool:
	RunManager.sync_seen_from_run_state()

	var meta: Node = get_node_or_null("/root/MetaProgression")
	if meta != null and meta.has_method("save_profile"):
		meta.call("save_profile")

	var payload: Dictionary = {}
	payload["saved_at_unix"] = Time.get_unix_time_from_system()
	payload["scene_path"] = _get_current_scene_path()
	payload["run_state"] = RunManager.export_state()
	if meta != null and meta.has_method("export_state"):
		payload["meta_state"] = meta.call("export_state")

	var text: String = JSON.stringify(payload, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: failed to open save file for write")
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true


func load_run() -> bool:
	if not has_save():
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: failed to open save file for read")
		return false
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: invalid save payload")
		return false
	var payload: Dictionary = parsed
	var run_state_any: Variant = payload.get("run_state", {})
	if typeof(run_state_any) != TYPE_DICTIONARY:
		push_error("SaveSystem: missing run_state")
		return false

	RunManager.import_state(run_state_any as Dictionary)
	var meta_node: Node = get_node_or_null("/root/MetaProgression")
	var meta_state_any: Variant = payload.get("meta_state", {})
	if meta_node != null and meta_node.has_method("import_state_merge") and typeof(meta_state_any) == TYPE_DICTIONARY:
		meta_node.call("import_state_merge", meta_state_any)

	var scene_path: String = str(payload.get("scene_path", ""))
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		scene_path = RunManager.get_scene_for_floor(RunManager.current_floor)
	if scene_path == "res://fight.tscn" and RunManager.current_enemy_data == null:
		scene_path = RunManager.get_scene_for_floor(RunManager.current_floor)

	get_tree().call_deferred("change_scene_to_file", scene_path)
	return true


func simulate_runs(count: int = 100) -> Dictionary:
	return _simulate_runs_internal(count, max(1, RunManager.current_floor), "mixed")


func simulate_breakdown(count: int = 100, floor: int = -1) -> Dictionary:
	var target_floor: int = max(1, RunManager.current_floor if floor <= 0 else floor)
	var mixed: Dictionary = _simulate_runs_internal(count, target_floor, "mixed")
	var normal: Dictionary = _simulate_runs_internal(count, target_floor, "normal")
	var elite: Dictionary = _simulate_runs_internal(count, target_floor, "elite")
	return {
		"floor": target_floor,
		"mixed": mixed,
		"normal": normal,
		"elite": elite,
	}


func simulate_floor_range_csv(count_per_floor: int = 100, floor_from: int = 1, floor_to: int = 10) -> String:
	var from_floor: int = min(floor_from, floor_to)
	var to_floor: int = max(floor_from, floor_to)
	var lines: PackedStringArray = []
	lines.append("floor,mode,runs,wins,winrate,avg_turns,avg_hp_left")

	for floor in range(from_floor, to_floor + 1):
		var mixed: Dictionary = _simulate_runs_internal(count_per_floor, floor, "mixed")
		var normal: Dictionary = _simulate_runs_internal(count_per_floor, floor, "normal")
		var elite: Dictionary = _simulate_runs_internal(count_per_floor, floor, "elite")
		lines.append(_sim_dict_to_csv_row(floor, "mixed", mixed))
		lines.append(_sim_dict_to_csv_row(floor, "normal", normal))
		lines.append(_sim_dict_to_csv_row(floor, "elite", elite))

	var file: FileAccess = FileAccess.open(SIM_CSV_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: failed to write sim csv")
		return ""
	file.store_string("\n".join(lines))
	file.flush()
	file.close()
	return SIM_CSV_PATH


func _simulate_runs_internal(count: int, floor: int, mode: String) -> Dictionary:
	var runs: int = maxi(1, count)
	var wins: int = 0
	var total_turns: float = 0.0
	var total_hp_left: float = 0.0
	var backup_enemy: EnemyData = RunManager.current_enemy_data
	var backup_elite: bool = RunManager.current_enemy_is_elite

	for _i in range(runs):
		var result: Dictionary = _simulate_single_fight(max(1, floor), mode)
		if bool(result.get("win", false)):
			wins += 1
		total_turns += float(result.get("turns", 0.0))
		total_hp_left += float(result.get("hp_left", 0.0))

	var out: Dictionary = {}
	out["runs"] = runs
	out["wins"] = wins
	out["winrate"] = float(wins) / float(runs)
	out["avg_turns"] = total_turns / float(runs)
	out["avg_hp_left"] = total_hp_left / float(runs)
	RunManager.current_enemy_data = backup_enemy
	RunManager.current_enemy_is_elite = backup_elite
	return out


func _simulate_single_fight(floor: int, mode: String = "mixed") -> Dictionary:
	var enemy_pick: Dictionary = _pick_enemy_for_floor_sim(floor, mode)
	var enemy: EnemyData = enemy_pick.get("enemy") as EnemyData
	if enemy == null:
		return {"win": false, "turns": 0, "hp_left": 0}
	var is_elite: bool = bool(enemy_pick.get("is_elite", false))

	var hp_mult: float = 1.0
	var dmg_mult: float = 1.0
	if RunManager.is_night:
		hp_mult = RunManager.night_enemy_hp_multiplier
		dmg_mult = RunManager.night_enemy_damage_multiplier
	if is_elite:
		hp_mult *= 1.5
		dmg_mult *= 1.35

	var enemy_count: int = _pick_enemy_count_sim(enemy)
	var one_enemy_hp: float = float(enemy.base_hp + floor * 4) * hp_mult
	var one_enemy_damage: float = float(enemy.base_damage + floor) * dmg_mult
	var total_enemy_hp: float = one_enemy_hp * float(enemy_count)
	var enemy_damage_scale: float = 1.0
	var vuln_mult_on_player: float = 1.0

	var player_hp: float = float(max(1, RunManager.current_hp))
	var deck_stats: Dictionary = _estimate_deck_power(RunManager.deck)
	var player_dpt: float = float(deck_stats.get("dpt", 8.0))
	var player_block: float = float(deck_stats.get("block", 5.0))
	var control_score: float = float(deck_stats.get("control", 0.0))

	var turns: int = 0
	while turns < 30 and player_hp > 0.0 and total_enemy_hp > 0.0:
		turns += 1

		var dealt: float = player_dpt * randf_range(0.88, 1.14)
		if control_score > 0.0 and randf() < clampf(control_score * 0.03, 0.0, 0.35):
			dealt *= 1.12
		total_enemy_hp -= dealt
		if total_enemy_hp <= 0.0:
			break

		var incoming: float = 0.0
		for _e in range(enemy_count):
			var intent: int = EnemyData.Intent.ATTACK
			if not enemy.battle_actions.is_empty():
				intent = int(enemy.battle_actions.pick_random())
			match intent:
				EnemyData.Intent.ATTACK:
					incoming += one_enemy_damage * enemy_damage_scale
				EnemyData.Intent.BUFF:
					enemy_damage_scale += 0.08
				EnemyData.Intent.DEBUFF:
					vuln_mult_on_player = minf(1.4, vuln_mult_on_player + 0.05)
				_:
					pass

		var blocked: float = player_block * randf_range(0.82, 1.18)
		var taken: float = maxf(0.0, incoming - blocked)
		player_hp -= taken * vuln_mult_on_player

	var win: bool = player_hp > 0.0 and total_enemy_hp <= 0.0
	return {"win": win, "turns": turns, "hp_left": maxf(0.0, player_hp)}


func _pick_enemy_for_floor_sim(floor: int, forced_mode: String = "mixed") -> Dictionary:
	RunManager._ensure_enemy_pools_for_current_act()
	var diff: String = "NORMAL"
	match forced_mode:
		"normal":
			diff = "NORMAL"
		"elite":
			diff = "ELITE"
		"boss":
			diff = "BOSS"
		_:
			if floor <= 2:
				diff = "NORMAL"
			elif floor == RunManager.boss_floor:
				diff = "BOSS"
			elif randf() < RunManager.elite_chance:
				diff = "ELITE"

	var pool: Array[EnemyData] = []
	match diff:
		"ELITE":
			pool = RunManager.elite_enemies
		"BOSS":
			pool = RunManager.boss_enemies
		_:
			pool = RunManager.normal_enemies

	if pool.is_empty():
		pool = RunManager.normal_enemies
	if pool.is_empty():
		pool = RunManager.elite_enemies
	if pool.is_empty():
		pool = RunManager.boss_enemies
	if pool.is_empty():
		return {"enemy": null, "is_elite": false}
	return {"enemy": pool.pick_random() as EnemyData, "is_elite": diff == "ELITE"}


func _pick_enemy_count_sim(enemy: EnemyData) -> int:
	if enemy == null:
		return 1
	if enemy.difficulty == EnemyData.Difficulty.BOSS:
		return 1
	if RunManager.multi_enemy_max_count < 2:
		return 1
	if randf() >= RunManager.multi_enemy_chance:
		return 1
	return randi_range(2, RunManager.multi_enemy_max_count)


func _estimate_deck_power(deck: Array[CardData]) -> Dictionary:
	var count: int = 0
	var attack_sum: float = 0.0
	var defense_sum: float = 0.0
	var control: float = 0.0
	var free_cards: int = 0

	for card in deck:
		if card == null:
			continue
		count += 1
		var cost: int = max(0, card.get_cost())
		var dmg: int = max(0, card.get_damage())
		var block: int = max(0, card.get_defense())
		attack_sum += float(dmg) / float(max(1, cost))
		defense_sum += float(block) / float(max(1, cost))
		if cost == 0:
			free_cards += 1
		if card.has_effect():
			control += 0.5
		if card.buff_kind != CardData.BuffKind.NONE:
			control += 0.6
		if card.get_hits_all_enemies():
			control += 0.7

	if count == 0:
		return {"dpt": 7.0, "block": 4.0, "control": 0.0}

	var avg_attack: float = attack_sum / float(count)
	var avg_defense: float = defense_sum / float(count)
	var dpt: float = 4.0 + avg_attack * 1.55 + float(free_cards) * 0.22
	var blk: float = 2.0 + avg_defense * 1.25
	return {"dpt": dpt, "block": blk, "control": control}


func _get_current_scene_path() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return RunManager.get_scene_for_floor(RunManager.current_floor)
	var path: String = str(scene.scene_file_path)
	if path == "":
		return RunManager.get_scene_for_floor(RunManager.current_floor)
	return path


func _sim_dict_to_csv_row(floor: int, mode: String, data: Dictionary) -> String:
	var runs: int = int(data.get("runs", 0))
	var wins: int = int(data.get("wins", 0))
	var winrate: float = float(data.get("winrate", 0.0))
	var avg_turns: float = float(data.get("avg_turns", 0.0))
	var avg_hp_left: float = float(data.get("avg_hp_left", 0.0))
	return "%d,%s,%d,%d,%.4f,%.4f,%.4f" % [floor, mode, runs, wins, winrate, avg_turns, avg_hp_left]
