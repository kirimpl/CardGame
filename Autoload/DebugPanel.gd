extends CanvasLayer

var panel: PanelContainer
var body: VBoxContainer
var status_label: Label
var sim_label: Label


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
	RunManager.toggle_day_night()
	status_label.text = "Time: %s" % ("Night" if RunManager.is_night else "Day")


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
