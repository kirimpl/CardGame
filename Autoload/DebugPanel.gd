extends CanvasLayer

var panel: PanelContainer
var body: VBoxContainer
var status_label: Label
var sim_label: Label
var scenario_floor_spin: SpinBox
var scenario_enemy_select: OptionButton
var scenario_mutator_select: OptionButton
var scenario_time_select: OptionButton
var scenario_enemy_pool: Array[EnemyData] = []


func _ready() -> void:
	layer = 200
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "DebugPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.offset_right = 300.0
	panel.offset_bottom = 430.0
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)

	var title: Label = Label.new()
	title.text = "DEBUG (F3)"
	body.add_child(title)

	_add_btn("Save Run", _on_save_run)
	_add_btn("Load Run", _on_load_run)
	_add_btn("Clear Save", _on_clear_save)
	_add_btn("Add Gold +100", _on_add_gold)
	_add_btn("Heal Full", _on_heal_full)
	_add_btn("Take Damage 10", _on_take_damage)
	_add_btn("Next Floor", _on_next_floor)
	_add_btn("Toggle Day/Night", _on_toggle_day_night)
	_add_btn("Give Flux +1", _on_add_flux)
	_add_btn("Set Floor 5", _on_set_floor_5)
	_add_btn("Set Floor 9", _on_set_floor_9)
	_add_btn("Export Combat Log", _on_export_combat_log)
	_add_btn("Export Replay JSON", _on_export_replay_log)
	_build_scenario_runner()
	_add_btn("Simulate 100 Fights", _on_simulate)
	_add_btn("Sim Breakdown x100", _on_simulate_breakdown)
	_add_btn("Export Floors 1-10 CSV", _on_export_sim_csv)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(260, 36)
	status_label.text = "Ready."
	body.add_child(status_label)

	sim_label = Label.new()
	sim_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sim_label.custom_minimum_size = Vector2(260, 110)
	body.add_child(sim_label)


func _build_scenario_runner() -> void:
	var sep: HSeparator = HSeparator.new()
	body.add_child(sep)
	var title: Label = Label.new()
	title.text = "Scenario Runner"
	body.add_child(title)

	scenario_floor_spin = SpinBox.new()
	scenario_floor_spin.min_value = 1
	scenario_floor_spin.max_value = 50
	scenario_floor_spin.value = max(1, RunManager.current_floor)
	body.add_child(scenario_floor_spin)

	scenario_enemy_select = OptionButton.new()
	_load_enemy_pool_for_scenario()
	body.add_child(scenario_enemy_select)

	scenario_mutator_select = OptionButton.new()
	scenario_mutator_select.add_item(RunManager.MUTATOR_NONE)
	scenario_mutator_select.add_item(RunManager.MUTATOR_BLEED_X2)
	scenario_mutator_select.add_item(RunManager.MUTATOR_HEAL_HALF)
	scenario_mutator_select.add_item(RunManager.MUTATOR_FIRST_SKILL_FREE)
	scenario_mutator_select.add_item(RunManager.MUTATOR_FIRST_ATTACK_BONUS)
	body.add_child(scenario_mutator_select)

	scenario_time_select = OptionButton.new()
	scenario_time_select.add_item("Day")
	scenario_time_select.add_item("Night")
	body.add_child(scenario_time_select)

	_add_btn("Start Scenario Fight", _on_start_scenario_fight)


func _load_enemy_pool_for_scenario() -> void:
	scenario_enemy_pool.clear()
	if scenario_enemy_select != null:
		scenario_enemy_select.clear()
	RunManager._ensure_enemy_pools_for_current_act()
	var idx: int = 0
	for e in RunManager.normal_enemies:
		if e == null:
			continue
		scenario_enemy_pool.append(e)
		scenario_enemy_select.add_item("N: " + e.name, idx)
		idx += 1
	for e in RunManager.elite_enemies:
		if e == null:
			continue
		scenario_enemy_pool.append(e)
		scenario_enemy_select.add_item("E: " + e.name, idx)
		idx += 1
	for e in RunManager.boss_enemies:
		if e == null:
			continue
		scenario_enemy_pool.append(e)
		scenario_enemy_select.add_item("B: " + e.name, idx)
		idx += 1


func _add_btn(text: String, cb: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.pressed.connect(cb)
	body.add_child(btn)


func _on_save_run() -> void:
	var ok: bool = SaveSystem.save_run()
	status_label.text = "Save: %s" % ("OK" if ok else "FAILED")


func _on_load_run() -> void:
	var ok: bool = SaveSystem.load_run()
	status_label.text = "Load: %s" % ("OK" if ok else "NO SAVE / FAILED")


func _on_clear_save() -> void:
	SaveSystem.clear_save()
	status_label.text = "Save cleared."


func _on_add_gold() -> void:
	RunManager.gold += 100
	status_label.text = "Gold: %d" % RunManager.gold


func _on_heal_full() -> void:
	RunManager.current_hp = RunManager.max_hp
	status_label.text = "HP: %d/%d" % [RunManager.current_hp, RunManager.max_hp]


func _on_take_damage() -> void:
	RunManager.current_hp = max(1, RunManager.current_hp - 10)
	status_label.text = "HP: %d/%d" % [RunManager.current_hp, RunManager.max_hp]


func _on_next_floor() -> void:
	RunManager.next_floor()
	status_label.text = "Going to floor %d..." % RunManager.current_floor


func _on_toggle_day_night() -> void:
	var ok: bool = RunManager.toggle_day_night(true)
	if not ok:
		status_label.text = "Not enough Flux."
		return
	status_label.text = "Time: %s | Flux: %d" % [("Night" if RunManager.is_night else "Day"), int(RunManager.time_shards)]


func _on_add_flux() -> void:
	RunManager.time_shards = min(RunManager.max_time_shards, RunManager.time_shards + 1)
	status_label.text = "Flux: %d" % int(RunManager.time_shards)


func _on_set_floor_5() -> void:
	RunManager.current_floor = 5
	RunManager.current_floor_mutator = RunManager.roll_floor_mutator_for_floor(5)
	status_label.text = "Floor set to 5 (%s)" % RunManager.get_current_floor_mutator_display()


func _on_set_floor_9() -> void:
	RunManager.current_floor = 9
	RunManager.current_floor_mutator = RunManager.roll_floor_mutator_for_floor(9)
	status_label.text = "Floor set to 9 (%s)" % RunManager.get_current_floor_mutator_display()


func _on_export_combat_log() -> void:
	var path: String = SaveSystem.export_combat_log(240)
	status_label.text = "Combat log: %s" % (path if path != "" else "export failed")


func _on_export_replay_log() -> void:
	var path: String = SaveSystem.export_replay_log(2000)
	status_label.text = "Replay: %s" % (path if path != "" else "export failed")


func _on_start_scenario_fight() -> void:
	if scenario_enemy_pool.is_empty():
		status_label.text = "No enemies in pool"
		return
	var enemy_idx: int = scenario_enemy_select.selected
	if enemy_idx < 0 or enemy_idx >= scenario_enemy_pool.size():
		enemy_idx = 0
	var enemy_data: EnemyData = scenario_enemy_pool[enemy_idx]
	if enemy_data == null:
		status_label.text = "Enemy is null"
		return

	RunManager.current_floor = int(round(scenario_floor_spin.value))
	RunManager.current_enemy_data = enemy_data
	RunManager.current_enemy_is_elite = (enemy_data.difficulty == EnemyData.Difficulty.ELITE)
	RunManager.current_floor_mutator = scenario_mutator_select.get_item_text(scenario_mutator_select.selected)
	RunManager.forced_room_type = RunManager.ROOM_ENEMY
	RunManager.is_night = (scenario_time_select.selected == 1)
	RunManager.returning_from_fight = false
	RunManager.reward_claimed = false
	status_label.text = "Scenario -> fight (%s)" % enemy_data.name
	get_tree().call_deferred("change_scene_to_file", "res://fight.tscn")


func _on_simulate() -> void:
	var result: Dictionary = SaveSystem.simulate_runs(100)
	var winrate: float = float(result.get("winrate", 0.0)) * 100.0
	var avg_turns: float = float(result.get("avg_turns", 0.0))
	var avg_hp: float = float(result.get("avg_hp_left", 0.0))
	sim_label.text = "SIM x100\nWinrate: %.1f%%\nAvg turns: %.2f\nAvg HP left: %.1f" % [winrate, avg_turns, avg_hp]


func _on_simulate_breakdown() -> void:
	var result: Dictionary = SaveSystem.simulate_breakdown(100, RunManager.current_floor)
	var mixed: Dictionary = result.get("mixed", {})
	var normal: Dictionary = result.get("normal", {})
	var elite: Dictionary = result.get("elite", {})
	sim_label.text = "SIM x100 Floor %d\nMIX %.1f%% | N %.1f%% | E %.1f%%\nTurns M/N/E: %.2f / %.2f / %.2f\nHP M/N/E: %.1f / %.1f / %.1f" % [
		int(result.get("floor", RunManager.current_floor)),
		float(mixed.get("winrate", 0.0)) * 100.0,
		float(normal.get("winrate", 0.0)) * 100.0,
		float(elite.get("winrate", 0.0)) * 100.0,
		float(mixed.get("avg_turns", 0.0)),
		float(normal.get("avg_turns", 0.0)),
		float(elite.get("avg_turns", 0.0)),
		float(mixed.get("avg_hp_left", 0.0)),
		float(normal.get("avg_hp_left", 0.0)),
		float(elite.get("avg_hp_left", 0.0)),
	]


func _on_export_sim_csv() -> void:
	var path: String = SaveSystem.simulate_floor_range_csv(100, 1, 10)
	if path == "":
		status_label.text = "CSV export failed"
	else:
		status_label.text = "CSV exported: %s" % path
