extends Node2D

const RELIC_FALLBACK_ICON: Texture2D = preload("res://icon.svg")

@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var starting_deck: Array[CardData] = []
@export var starting_relics: Array[RelicData] = []
@export var card_view_scene: PackedScene
@export_group("Combat Tuning")
@export var dash_time: float = 0.2
@export var player_spawn_scale: Vector2 = Vector2(1.3, 1.3)
@export var enemy_spawn_scale: Vector2 = Vector2(1.3, 1.3)
@export var default_energy_max: int = 3
@export var default_hand_size: int = 5
@export var default_enchant_effect: EffectData = preload("res://Cards/Effects/Burn.tres")
@export var default_enchant_effect_durability: int = 1
@export var default_enchant_charges: int = 2
@export var enemy_spacing: float = 160.0
@export var target_pick_radius: float = 240.0
@export var damage_popup_duration: float = 0.5
@export var damage_popup_rise: float = 38.0

@onready var player_anchor: Marker2D = $"../PlayerAnchor"
@onready var enemy_anchor: Marker2D = $"../EnemyAnchor"
@onready var ui_root: Node = $"../UI/HudRoot"

@onready var ui_player_bar: Control = ui_root.get_node("PlayerBar")
@onready var ui_player_bar_back: ColorRect = ui_player_bar.get_node("Back")
@onready var ui_player_bar_fill: ColorRect = ui_player_bar.get_node("Fill")
@onready var ui_player_bar_text: Label = ui_player_bar.get_node("Text")

@onready var ui_enemy_hp: Label = ui_root.get_node("TopBar/Margin/Row/RightGroup/EnemyHP")
@onready var ui_gold: Label = ui_root.get_node("TopBar/Margin/Row/LeftGroup/GoldLabel")
@onready var ui_speed_btn: Button = ui_root.get_node("TopBar/Margin/Row/LeftGroup/SpeedBtn")
@onready var ui_enemy_intent: Label = ui_root.get_node("EnemyIntent")
@onready var ui_enemy_bar: Control = ui_root.get_node("EnemyBar")
@onready var ui_enemy_bar_back: ColorRect = ui_enemy_bar.get_node("Back")
@onready var ui_enemy_bar_fill: ColorRect = ui_enemy_bar.get_node("Fill")
@onready var ui_enemy_bar_text: Label = ui_enemy_bar.get_node("Text")
@onready var ui_enemy_status: HBoxContainer = ui_root.get_node("EnemyStatus")
@onready var end_btn: Button = ui_root.get_node("EndTurnBtn")
@onready var hand_root: Control = $"../UI/HandRoot"
@onready var hand_controller: Control = $"../UI/HandRoot/Hand"
@onready var ui_turn_label: Label = ui_root.get_node_or_null("TurnLabel")
@onready var ui_deck: Label = ui_root.get_node("PlayerPanel/Margin/VBox/DeckLabel")
@onready var ui_discard: Label = ui_root.get_node("PlayerPanel/Margin/VBox/DiscardLabel")
@onready var ui_exhaust: Label = ui_root.get_node_or_null("PlayerPanel/Margin/VBox/ExhaustLabel")
@onready var ui_energy: Label = ui_root.get_node("PlayerPanel/Margin/VBox/EnergyLabel")
@onready var ui_buff_stacks: Label = ui_root.get_node_or_null("PlayerPanel/Margin/VBox/BuffStacksLabel")
@onready var ui_energy_orb_label: Label = ui_root.get_node_or_null("EnergyOrb/Value")

var player: Node2D
var enemies: Array[Node2D] = []
var player_turn: bool = true
var busy: bool = false

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var exhaust_pile: Array[CardData] = []
var hand: Array[CardData] = []

var energy_max: int = 3
var energy: int = 3
var hand_size: int = 5
var player_defense: int = 0
var turn_number: int = 1
var player_turns_started: int = 0
var enchant_attack_charges: int = 0
var enchant_effect: EffectData = null
var enchant_effect_durability: int = 0
var player_effects: Dictionary = {}
var pending_target_card: CardData = null
var target_preview_enemy: Node2D = null

var pile_overlay: Control = null
var pile_title_label: Label = null
var pile_cards_grid: GridContainer = null

var relic_panel: PanelContainer = null
var relic_icons_row: HBoxContainer = null
var relic_tooltip: PanelContainer = null
var relic_tooltip_title: Label = null
var relic_tooltip_desc: Label = null
var relic_signature_cached: String = ""
var ui_time_label: Label = null
var ui_player_status_row: HBoxContainer = null
var status_tooltip: PanelContainer = null
var status_tooltip_title: Label = null
var status_tooltip_desc: Label = null
var enemy_status_signature: String = ""
var player_status_signature: String = ""
var combat_log_panel: PanelContainer = null
var combat_log_text: RichTextLabel = null
var combat_log_toggle_btn: Button = null
var combat_log_filter: OptionButton = null
var save_exit_btn: Button = null
var damage_preview_label: Label = null
var last_player_hp_display: int = -1
var last_player_block_display: int = -1


func _ready() -> void:
	if not _assert_ui():
		return

	end_btn.pressed.connect(_on_end_turn_pressed)
	_setup_pile_ui()
	_setup_relic_panel()
	_setup_time_label()
	_setup_player_status_row()
	_setup_status_tooltip()
	_setup_combat_log_ui()
	_setup_damage_preview_ui()
	_setup_save_exit_button()
	_bind_pile_label_events()

	if ui_speed_btn != null:
		ui_speed_btn.pressed.connect(_on_speed_pressed)
		ui_speed_btn.text = "x" + str(RunManager.battle_speed_mult)

	Engine.time_scale = float(RunManager.battle_speed_mult)
	_set_buttons_enabled(false)
	energy_max = max(1, default_energy_max)
	hand_size = max(1, default_hand_size)

	await get_tree().process_frame
	await _spawn_combatants()
	_ensure_starting_relics()
	for relic in RunManager.relics:
		if relic != null:
			RunManager.mark_relic_seen(relic.id)
	var enemy_name: String = RunManager.current_enemy_data.name if RunManager.current_enemy_data != null else "Enemy"
	if RunManager.current_enemy_data != null:
		RunManager.mark_enemy_seen(RunManager.current_enemy_data.resource_path)
	_log_turn_action("System", "FightStart", "vs %s on floor %d" % [enemy_name, RunManager.current_floor])

	_setup_deck()
	_update_ui()
	_update_energy_ui()
	_update_deck_ui()
	_refresh_hand_ui()

	player_turn = (GameState.starter == GameState.Starter.PLAYER)
	_start_turn()


func _spawn_combatants() -> void:
	var root: Node = get_tree().current_scene
	player = player_scene.instantiate()
	root.call_deferred("add_child", player)

	var enemy_count: int = RunManager.get_fight_enemy_count()
	for i in range(enemy_count):
		var enemy_instance: Node2D = enemy_scene.instantiate()
		root.call_deferred("add_child", enemy_instance)
		enemies.append(enemy_instance)

	await get_tree().process_frame

	player.global_position = player_anchor.global_position
	player.z_index = 10
	player.scale = player_spawn_scale

	var total_width: float = enemy_spacing * float(max(0, enemies.size() - 1))
	for i in range(enemies.size()):
		var enemy_instance: Node2D = enemies[i]
		var x_offset: float = (-total_width * 0.5) + (enemy_spacing * float(i))
		enemy_instance.global_position = enemy_anchor.global_position + Vector2(x_offset, 0.0)
		enemy_instance.z_index = 10
		enemy_instance.scale = enemy_spawn_scale
		if RunManager.current_enemy_data != null:
			enemy_instance.setup(RunManager.current_enemy_data, RunManager.current_floor, RunManager.current_enemy_is_elite)
		if enemy_instance.has_signal("hit_player"):
			var cb: Callable = Callable(self, "_on_enemy_hit_player").bind(enemy_instance)
			if not enemy_instance.hit_player.is_connected(cb):
				enemy_instance.hit_player.connect(cb)
		if enemy_instance.has_signal("apply_player_effects"):
			var cb_effects: Callable = Callable(self, "_on_enemy_apply_player_effects")
			if not enemy_instance.apply_player_effects.is_connected(cb_effects):
				enemy_instance.apply_player_effects.connect(cb_effects)
		if enemy_instance.has_signal("damage_taken"):
			var cb_damage: Callable = Callable(self, "_on_enemy_damage_taken").bind(enemy_instance)
			if not enemy_instance.damage_taken.is_connected(cb_damage):
				enemy_instance.damage_taken.connect(cb_damage)

	if RunManager.current_enemy_data == null:
		push_error("BattleManager: no enemy data")


func _get_alive_enemies() -> Array[Node2D]:
	var alive: Array[Node2D] = []
	for enemy_instance in enemies:
		if enemy_instance == null:
			continue
		if not is_instance_valid(enemy_instance):
			continue
		if "hp" in enemy_instance and int(enemy_instance.hp) <= 0:
			continue
		alive.append(enemy_instance)
	return alive


func _get_primary_enemy() -> Node2D:
	var alive: Array[Node2D] = _get_alive_enemies()
	if alive.is_empty():
		return null
	return alive[0]


func _all_enemies_dead() -> bool:
	return _get_alive_enemies().is_empty()


func _update_ui() -> void:
	if ui_gold != null:
		ui_gold.text = "Gold: %d" % int(RunManager.gold)

	var p_hp: int = int(RunManager.current_hp)
	var p_max: int = int(RunManager.max_hp)
	var hp_changed: bool = (last_player_hp_display != -1 and last_player_hp_display != p_hp)
	var block_changed: bool = (last_player_block_display != -1 and last_player_block_display != player_defense)
	last_player_hp_display = p_hp
	last_player_block_display = player_defense
	var p_ratio: float = float(p_hp) / float(max(1, p_max))
	if ui_player_bar_fill != null and ui_player_bar_back != null:
		ui_player_bar_fill.size.x = ui_player_bar.size.x * p_ratio
		ui_player_bar_back.size = ui_player_bar.size
		if player_defense > 0:
			ui_player_bar_back.color = Color(0.08, 0.12, 0.35, 1)
			ui_player_bar_fill.color = Color(0.15, 0.35, 0.85, 1)
			ui_player_bar_text.text = "Block %d   HP %d/%d" % [player_defense, p_hp, p_max]
		else:
			ui_player_bar_back.color = Color(0.35, 0.1, 0.1, 1)
			ui_player_bar_fill.color = Color(0.8, 0.2, 0.2, 1)
			ui_player_bar_text.text = "HP %d/%d" % [p_hp, p_max]
		if hp_changed or block_changed:
			_flash_label(ui_player_bar_text)

	var focus_enemy: Node2D = _get_primary_enemy()
	if focus_enemy != null:
		var e_name: String = "Enemy"
		if "data" in focus_enemy and focus_enemy.data != null:
			e_name = str(focus_enemy.data.name)
		if RunManager.current_enemy_is_elite:
			e_name = "Elite " + e_name
		if enemies.size() > 1:
			e_name += " x%d" % _get_alive_enemies().size()
		ui_enemy_hp.text = e_name

		var maxv: int = int(focus_enemy.max_hp) if ("max_hp" in focus_enemy) else 1
		maxv = max(1, maxv)
		var hpv: int = max(0, int(focus_enemy.hp))
		var block: int = int(focus_enemy.current_defense) if ("current_defense" in focus_enemy) else 0
		var ratio: float = float(hpv) / float(maxv)

		ui_enemy_bar_fill.size.x = ui_enemy_bar.size.x * ratio
		ui_enemy_bar_back.size = ui_enemy_bar.size
		if block > 0:
			ui_enemy_bar_back.color = Color(0.08, 0.12, 0.35, 1)
			ui_enemy_bar_fill.color = Color(0.15, 0.35, 0.85, 1)
			ui_enemy_bar_text.text = "Block %d   HP %d/%d" % [block, hpv, maxv]
		else:
			ui_enemy_bar_back.color = Color(0.35, 0.1, 0.1, 1)
			ui_enemy_bar_fill.color = Color(0.8, 0.2, 0.2, 1)
			ui_enemy_bar_text.text = "HP %d/%d" % [hpv, maxv]

		var intent_parts: PackedStringArray = []
		for e in _get_alive_enemies():
			if not ("current_intent" in e):
				continue
			var p: String = ""
			var intent: int = int(e.current_intent)
			match intent:
				EnemyData.Intent.ATTACK:
					var d: int = int(e.get_effective_attack_damage()) if e.has_method("get_effective_attack_damage") else int(e.damage)
					p = "ATK %d" % d
				EnemyData.Intent.DEFEND:
					p = "DEF +5"
				EnemyData.Intent.BUFF:
					p = "BUFF"
				EnemyData.Intent.DEBUFF:
					p = "Debuff"
			if p != "":
				intent_parts.append(p)
		if pending_target_card != null:
			ui_enemy_intent.text = "Choose target for: %s (RMB cancel)" % pending_target_card.get_display_title()
		else:
			ui_enemy_intent.text = "Intent: %s" % " | ".join(intent_parts)

		if focus_enemy.has_method("get_effect_details"):
			var effs: Dictionary = focus_enemy.get_effect_details()
			var sig: String = _build_effect_signature(effs)
			if sig != enemy_status_signature:
				enemy_status_signature = sig
				for c in ui_enemy_status.get_children():
					c.queue_free()
				if status_tooltip != null:
					status_tooltip.visible = false
				for k in effs.keys():
					var d: Dictionary = effs[k]
					var stacks: int = int(d.get("stacks", 1))
					var dur: int = int(d.get("duration", 0))
					var title: String = str(d.get("title", k))
					var desc: String = str(d.get("description", ""))
					var l: Label = Label.new()
					l.text = "%s x%d" % [title, stacks]
					if dur > 0:
						l.text += " (%d)" % dur
					_bind_status_tooltip(l, title, desc)
					ui_enemy_status.add_child(l)
	else:
		ui_enemy_hp.text = "No Enemies"
		ui_enemy_intent.text = ""
		ui_enemy_bar_fill.size.x = 0.0
		ui_enemy_bar_text.text = "HP 0/0"
		for c in ui_enemy_status.get_children():
			c.queue_free()
		enemy_status_signature = ""

	if player != null and player.has_method("toggle_shield"):
		player.toggle_shield(player_defense > 0)

	if ui_buff_stacks != null:
		if enchant_attack_charges > 0:
			ui_buff_stacks.text = "Enchanted: %d" % enchant_attack_charges
			ui_buff_stacks.visible = true
		else:
			ui_buff_stacks.visible = false

	if ui_turn_label != null:
		ui_turn_label.text = "Turn: %d" % turn_number
	if ui_time_label != null:
		ui_time_label.text = "Time: %s" % ("Night" if RunManager.is_night else "Day")

	_refresh_relic_panel()
	_refresh_player_effects_ui()


func _assert_ui() -> bool:
	return ui_player_bar != null and ui_enemy_hp != null and end_btn != null and hand_controller != null and hand_root != null and ui_deck != null and ui_discard != null and ui_energy != null


func _append_combat_log(text: String) -> void:
	RunManager.log_combat(text)
	_refresh_combat_log_ui()


func _guess_log_category(action: String, actor: String) -> String:
	var a: String = action.strip_edges().to_lower()
	var who: String = actor.strip_edges().to_lower()
	if a.find("damage") != -1 or a.find("attack") != -1:
		return "DAMAGE"
	if a.find("effect") != -1 or a.find("buff") != -1 or a.find("debuff") != -1:
		return "EFFECT"
	if who == "system":
		return "SYSTEM"
	return "SYSTEM"


func _log_turn_action(actor: String, action: String, result: String) -> void:
	var category: String = _guess_log_category(action, actor)
	RunManager.log_combat_event(category, actor, action, result, turn_number)
	_refresh_combat_log_ui()


func _refresh_combat_log_ui() -> void:
	if combat_log_text == null:
		return
	combat_log_text.clear()
	var filter_value: String = "ALL"
	if combat_log_filter != null:
		filter_value = combat_log_filter.get_item_text(combat_log_filter.selected)
	var events: Array[Dictionary] = RunManager.get_combat_events_tail(24, filter_value)
	if events.is_empty():
		combat_log_text.append_text("No entries yet\n")
	for event_dict in events:
		var ev_turn: int = int(event_dict.get("turn", 0))
		var ev_actor: String = str(event_dict.get("actor", "System"))
		var ev_action: String = str(event_dict.get("action", ""))
		var ev_result: String = str(event_dict.get("result", ""))
		combat_log_text.append_text("Turn %d | %s | %s | %s\n" % [ev_turn, ev_actor, ev_action, ev_result])
	combat_log_text.scroll_to_line(combat_log_text.get_line_count())


func _setup_pile_ui() -> void:
	pile_overlay = Control.new()
	pile_overlay.name = "PileOverlay"
	pile_overlay.visible = false
	pile_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pile_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(pile_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	pile_overlay.add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 320)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_top = -160
	panel.offset_right = 210
	panel.offset_bottom = 160
	pile_overlay.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)

	pile_title_label = Label.new()
	pile_title_label.add_theme_font_size_override("font_size", 20)
	pile_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile_title_label.text = "Pile"
	vbox.add_child(pile_title_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(380, 240)
	vbox.add_child(scroll)

	pile_cards_grid = GridContainer.new()
	pile_cards_grid.columns = 3
	scroll.add_child(pile_cards_grid)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_hide_pile_overlay)
	vbox.add_child(close_btn)


func _setup_relic_panel() -> void:
	relic_panel = PanelContainer.new()
	relic_panel.name = "RelicPanel"
	relic_panel.anchor_left = 1.0
	relic_panel.anchor_top = 0.0
	relic_panel.anchor_right = 1.0
	relic_panel.anchor_bottom = 0.0
	relic_panel.offset_left = -330.0
	relic_panel.offset_top = 50.0
	relic_panel.offset_right = -10.0
	relic_panel.offset_bottom = 98.0
	relic_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_root.add_child(relic_panel)

	relic_icons_row = HBoxContainer.new()
	relic_icons_row.alignment = BoxContainer.ALIGNMENT_END
	relic_panel.add_child(relic_icons_row)

	relic_tooltip = PanelContainer.new()
	relic_tooltip.name = "RelicTooltip"
	relic_tooltip.visible = false
	relic_tooltip.custom_minimum_size = Vector2(260, 90)
	relic_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_tooltip.z_index = 20
	ui_root.add_child(relic_tooltip)

	var tooltip_vbox: VBoxContainer = VBoxContainer.new()
	relic_tooltip.add_child(tooltip_vbox)

	relic_tooltip_title = Label.new()
	relic_tooltip_title.add_theme_font_size_override("font_size", 16)
	tooltip_vbox.add_child(relic_tooltip_title)

	relic_tooltip_desc = Label.new()
	relic_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_vbox.add_child(relic_tooltip_desc)
	_refresh_relic_panel()


func _setup_time_label() -> void:
	ui_time_label = Label.new()
	ui_time_label.name = "TimeLabel"
	ui_time_label.offset_left = 470.0
	ui_time_label.offset_top = 6.0
	ui_time_label.offset_right = 620.0
	ui_time_label.offset_bottom = 34.0
	ui_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(ui_time_label)


func _setup_player_status_row() -> void:
	ui_player_status_row = HBoxContainer.new()
	ui_player_status_row.name = "PlayerStatusRow"
	ui_player_status_row.offset_left = 26.0
	ui_player_status_row.offset_top = 612.0
	ui_player_status_row.offset_right = 420.0
	ui_player_status_row.offset_bottom = 640.0
	ui_root.add_child(ui_player_status_row)


func _setup_status_tooltip() -> void:
	status_tooltip = PanelContainer.new()
	status_tooltip.visible = false
	status_tooltip.custom_minimum_size = Vector2(250.0, 80.0)
	status_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_tooltip.z_index = 30
	ui_root.add_child(status_tooltip)

	var vbox: VBoxContainer = VBoxContainer.new()
	status_tooltip.add_child(vbox)

	status_tooltip_title = Label.new()
	status_tooltip_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(status_tooltip_title)

	status_tooltip_desc = Label.new()
	status_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_tooltip_desc)


func _setup_combat_log_ui() -> void:
	combat_log_toggle_btn = Button.new()
	combat_log_toggle_btn.name = "CombatLogToggle"
	combat_log_toggle_btn.anchor_left = 1.0
	combat_log_toggle_btn.anchor_top = 1.0
	combat_log_toggle_btn.anchor_right = 1.0
	combat_log_toggle_btn.anchor_bottom = 1.0
	combat_log_toggle_btn.offset_left = -140.0
	combat_log_toggle_btn.offset_top = -42.0
	combat_log_toggle_btn.offset_right = -12.0
	combat_log_toggle_btn.offset_bottom = -10.0
	combat_log_toggle_btn.text = "Show Log"
	combat_log_toggle_btn.pressed.connect(_on_combat_log_toggle_pressed)
	ui_root.add_child(combat_log_toggle_btn)

	combat_log_panel = PanelContainer.new()
	combat_log_panel.name = "CombatLogPanel"
	combat_log_panel.anchor_left = 1.0
	combat_log_panel.anchor_top = 1.0
	combat_log_panel.anchor_right = 1.0
	combat_log_panel.anchor_bottom = 1.0
	combat_log_panel.offset_left = -382.0
	combat_log_panel.offset_top = -252.0
	combat_log_panel.offset_right = -12.0
	combat_log_panel.offset_bottom = -48.0
	combat_log_panel.visible = false
	ui_root.add_child(combat_log_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	combat_log_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Combat Log"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.93, 0.94, 0.98, 1.0))
	vbox.add_child(title)

	combat_log_filter = OptionButton.new()
	combat_log_filter.add_item("ALL")
	combat_log_filter.add_item("DAMAGE")
	combat_log_filter.add_item("EFFECT")
	combat_log_filter.add_item("SYSTEM")
	combat_log_filter.item_selected.connect(_on_combat_log_filter_changed)
	vbox.add_child(combat_log_filter)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	combat_log_text = RichTextLabel.new()
	combat_log_text.fit_content = true
	combat_log_text.scroll_active = true
	combat_log_text.selection_enabled = false
	combat_log_text.bbcode_enabled = false
	combat_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_log_text.custom_minimum_size = Vector2(320.0, 170.0)
	combat_log_text.add_theme_color_override("default_color", Color(0.93, 0.94, 0.98, 1.0))
	scroll.add_child(combat_log_text)
	_refresh_combat_log_ui()


func _setup_damage_preview_ui() -> void:
	damage_preview_label = Label.new()
	damage_preview_label.name = "DamagePreviewLabel"
	damage_preview_label.anchor_left = 0.5
	damage_preview_label.anchor_top = 0.0
	damage_preview_label.anchor_right = 0.5
	damage_preview_label.anchor_bottom = 0.0
	damage_preview_label.offset_left = -220.0
	damage_preview_label.offset_top = 88.0
	damage_preview_label.offset_right = 220.0
	damage_preview_label.offset_bottom = 116.0
	damage_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_preview_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
	damage_preview_label.visible = false
	ui_root.add_child(damage_preview_label)


func _on_combat_log_toggle_pressed() -> void:
	if combat_log_panel == null:
		return
	combat_log_panel.visible = not combat_log_panel.visible
	if combat_log_toggle_btn != null:
		combat_log_toggle_btn.text = "Hide Log" if combat_log_panel.visible else "Show Log"
	if combat_log_panel.visible:
		_refresh_combat_log_ui()


func _on_combat_log_filter_changed(_idx: int) -> void:
	_refresh_combat_log_ui()


func _setup_save_exit_button() -> void:
	save_exit_btn = Button.new()
	save_exit_btn.name = "SaveExitButton"
	save_exit_btn.anchor_left = 1.0
	save_exit_btn.anchor_top = 0.0
	save_exit_btn.anchor_right = 1.0
	save_exit_btn.anchor_bottom = 0.0
	save_exit_btn.offset_left = -232.0
	save_exit_btn.offset_top = 6.0
	save_exit_btn.offset_right = -10.0
	save_exit_btn.offset_bottom = 34.0
	save_exit_btn.text = "Save & Main Menu"
	save_exit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	save_exit_btn.pressed.connect(_on_save_exit_pressed)
	ui_root.add_child(save_exit_btn)


func _on_save_exit_pressed() -> void:
	SaveSystem.save_run()
	get_tree().change_scene_to_file("res://menu.tscn")


func _bind_status_tooltip(label: Label, title: String, desc: String) -> void:
	if label == null:
		return
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_HELP
	var cb_enter: Callable = Callable(self, "_on_status_label_mouse_entered").bind(label, title, desc)
	var cb_exit: Callable = Callable(self, "_on_status_label_mouse_exited")
	if not label.mouse_entered.is_connected(cb_enter):
		label.mouse_entered.connect(cb_enter)
	if not label.mouse_exited.is_connected(cb_exit):
		label.mouse_exited.connect(cb_exit)


func _on_status_label_mouse_entered(label: Label, title: String, desc: String) -> void:
	if status_tooltip == null or status_tooltip_title == null or status_tooltip_desc == null:
		return
	status_tooltip_title.text = title
	status_tooltip_desc.text = desc
	status_tooltip.visible = true
	var tip_size: Vector2 = status_tooltip.get_combined_minimum_size()
	var vp_size: Vector2 = get_viewport_rect().size
	var p: Vector2 = label.global_position + Vector2(0.0, -tip_size.y - 8.0)
	p.x = clampf(p.x, 4.0, maxf(4.0, vp_size.x - tip_size.x - 4.0))
	p.y = clampf(p.y, 4.0, maxf(4.0, vp_size.y - tip_size.y - 4.0))
	status_tooltip.global_position = p


func _on_status_label_mouse_exited() -> void:
	if status_tooltip != null:
		status_tooltip.visible = false


func _refresh_relic_panel() -> void:
	if relic_icons_row == null:
		return
	var new_signature: String = _build_relic_signature()
	if new_signature == relic_signature_cached:
		return
	relic_signature_cached = new_signature
	for child in relic_icons_row.get_children():
		child.queue_free()
	for relic in RunManager.relics:
		if relic == null:
			continue
		if not relic.is_active_for_time(RunManager.is_night):
			continue
		var icon_holder: TextureRect = TextureRect.new()
		icon_holder.custom_minimum_size = Vector2(34, 34)
		icon_holder.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_holder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_holder.mouse_filter = Control.MOUSE_FILTER_STOP
		icon_holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		icon_holder.texture = relic.icon if relic.icon != null else RELIC_FALLBACK_ICON
		icon_holder.mouse_entered.connect(_on_relic_icon_mouse_entered.bind(icon_holder, relic))
		icon_holder.mouse_exited.connect(_on_relic_icon_mouse_exited)
		relic_icons_row.add_child(icon_holder)
	if relic_tooltip != null:
		relic_tooltip.visible = false


func _build_relic_signature() -> String:
	if RunManager.relics.is_empty():
		return "-"
	var parts: PackedStringArray = []
	for relic in RunManager.relics:
		if relic == null:
			continue
		if not relic.is_active_for_time(RunManager.is_night):
			continue
		parts.append(relic.id + "|" + relic.get_display_name())
	return "||".join(parts)


func _ensure_starting_relics() -> void:
	if not RunManager.relics.is_empty():
		return
	for relic in starting_relics:
		RunManager.add_relic(relic)


func _on_relic_icon_mouse_entered(icon: TextureRect, relic: RelicData) -> void:
	if relic_tooltip == null or relic_tooltip_title == null or relic_tooltip_desc == null:
		return
	relic_tooltip_title.text = relic.get_display_name()
	relic_tooltip_desc.text = relic.description
	var size_hint: Vector2 = relic_tooltip.get_combined_minimum_size()
	relic_tooltip.global_position = icon.global_position + Vector2(-size_hint.x - 10.0, 8.0)
	relic_tooltip.visible = true


func _on_relic_icon_mouse_exited() -> void:
	if relic_tooltip != null:
		relic_tooltip.visible = false


func _bind_pile_label_events() -> void:
	_bind_clickable_label(ui_deck, _on_deck_label_gui_input)
	_bind_clickable_label(ui_discard, _on_discard_label_gui_input)
	if ui_exhaust != null:
		_bind_clickable_label(ui_exhaust, _on_exhaust_label_gui_input)


func _bind_clickable_label(label: Label, handler: Callable) -> void:
	if label == null:
		return
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not label.gui_input.is_connected(handler):
		label.gui_input.connect(handler)


func _setup_deck() -> void:
	draw_pile.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	hand.clear()
	turn_number = 1
	player_turns_started = 0
	enchant_attack_charges = 0
	enchant_effect = null
	enchant_effect_durability = 0

	if not RunManager.deck.is_empty():
		draw_pile = _duplicate_cards(RunManager.deck)
	elif not starting_deck.is_empty():
		draw_pile = _duplicate_cards(starting_deck)
		RunManager.deck = _duplicate_cards(starting_deck)
	for deck_card in RunManager.deck:
		if deck_card != null:
			RunManager.mark_card_seen(deck_card.id)
	_shuffle_cards(draw_pile)


func _duplicate_cards(cards: Array[CardData]) -> Array[CardData]:
	var out: Array[CardData] = []
	for c in cards:
		if c == null:
			continue
		var copy: CardData = c.duplicate(true) as CardData
		var final_card: CardData = copy if copy != null else c
		RunManager.apply_relic_card_modifiers(final_card)
		out.append(final_card)
	return out


func _shuffle_cards(cards: Array[CardData]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j: int = RunManager.rolli_range_run(0, i)
		var tmp: CardData = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


func _start_turn() -> void:
	if player_turn:
		await _start_player_turn_setup()
		_set_buttons_enabled(true)
	else:
		_set_buttons_enabled(false)
		await _enemy_action()


func _start_player_turn_setup() -> void:
	player_turns_started += 1
	turn_number = player_turns_started
	_log_turn_action("System", "TurnStart", "Player turn")
	energy = energy_max
	player_defense = 0
	if _tick_player_effects(EffectData.TickWhen.START_TURN):
		return
	_update_energy_ui()
	_update_ui()
	await _draw_cards(hand_size)
	_refresh_hand_ui()
	_update_deck_ui()


func _draw_cards(count: int) -> void:
	for _i in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			_shuffle_cards(draw_pile)
			discard_pile.clear()
		hand.append(draw_pile.pop_back())
	await get_tree().process_frame


func _refresh_hand_ui() -> void:
	if hand_controller == null:
		return
	if hand_controller.has_method("clear_hand"):
		hand_controller.clear_hand()
	else:
		for child in hand_controller.get_children():
			child.queue_free()

	for card in hand:
		var view: Node = card_view_scene.instantiate()
		if "use_physics" in view:
			view.use_physics = true
		if view.has_method("setup"):
			view.setup(card)
		if view.has_signal("played"):
			view.played.connect(_on_card_played.bind(card))
		if hand_controller.has_method("add_card_to_hand"):
			hand_controller.add_card_to_hand(view)
		else:
			hand_controller.add_child(view)


func _update_deck_ui() -> void:
	ui_deck.text = "Deck: %d" % draw_pile.size()
	ui_discard.text = "Discard: %d" % discard_pile.size()
	if ui_exhaust != null:
		ui_exhaust.text = "Exhaust: %d" % exhaust_pile.size()


func _update_energy_ui() -> void:
	ui_energy.text = "Energy: %d/%d" % [energy, energy_max]
	if ui_energy_orb_label != null:
		ui_energy_orb_label.text = "%d/%d" % [energy, energy_max]


func _on_card_played(card: CardData) -> void:
	if busy or not player_turn:
		return
	if not card.is_playable():
		return
	if energy < card.get_cost():
		return
	if _should_request_target(card):
		pending_target_card = card
		_set_target_prompt()
		return
	await _play_card(card, null)


func _play_card(card: CardData, forced_target: Node2D = null) -> void:
	busy = true
	_set_buttons_enabled(false)
	_log_turn_action("Player", "PlayCard", card.get_display_title())
	RunManager.mark_card_seen(card.id)

	var card_cost: int = card.get_cost()
	var card_damage: int = card.get_damage()
	var card_defense: int = card.get_defense()
	var card_effect: EffectData = card.get_effect()
	var card_buff_effect: EffectData = card.get_buff_effect()
	var card_buff_charges: int = card.get_buff_charges()

	energy -= card_cost
	_update_energy_ui()

	if card_defense > 0:
		var defense_mult: float = _get_player_block_multiplier()
		player_defense += int(round(float(card_defense) * defense_mult))

	if card.get_card_type() == CardData.CardType.BUFF and card.buff_kind == CardData.BuffKind.ENCHANT_ATTACK_EFFECT:
		var charges: int = max(1, card_buff_charges if card_buff_charges > 0 else default_enchant_charges)
		enchant_attack_charges += charges
		enchant_effect = card_buff_effect if card_buff_effect != null else default_enchant_effect
		if enchant_effect != null:
			enchant_effect_durability = max(1, card.get_buff_effect_durability() if card.get_buff_effect_durability() > 0 else default_enchant_effect_durability)
	elif card.get_card_type() == CardData.CardType.BUFF and card.buff_kind == CardData.BuffKind.APPLY_SELF_EFFECT:
		var self_effect: EffectData = card_buff_effect
		var self_dur: int = max(1, card.get_buff_effect_durability())
		var self_val: int = max(1, card.get_buff_charges())
		if self_effect != null:
			var effect_copy: EffectData = self_effect.duplicate(true) as EffectData
			if effect_copy == null:
				effect_copy = self_effect
			if self_val > 0:
				effect_copy.value = self_val
			_apply_player_effect(effect_copy, self_dur, 1)

	var targets: Array[Node2D] = []
	if card.get_hits_all_enemies():
		targets = _get_alive_enemies()
	else:
		var single_target: Node2D = forced_target if forced_target != null else _get_primary_enemy()
		if single_target != null:
			targets.append(single_target)

	if card_damage > 0 and not targets.is_empty():
			var stop_pos: Vector2 = targets[0].global_position + Vector2(-80.0, 0.0)
			await _dash_to(player, stop_pos)
			if player.has_method("attack_sequence"):
				await player.call("attack_sequence", targets[0])

			var dmg_bonus: int = _get_player_effect_value("strength_surge")
			var outgoing_mult: float = _get_player_outgoing_damage_multiplier()
			for t in targets:
				if not is_instance_valid(t) or not t.has_method("take_damage"):
					continue
				var base_damage: int = card_damage + dmg_bonus
				var final_damage: int = max(0, int(round(float(base_damage) * outgoing_mult)))
				t.take_damage(final_damage)
				if final_damage > 0:
					_log_turn_action("Player", "Damage", "%s dealt %d" % [card.get_display_title(), final_damage])
				if card.has_method("has_effect") and card.has_effect() and t.has_method("apply_effect") and card_effect != null:
					var eff_dur: int = card.get_effect_durability()
					if eff_dur > 0:
						t.apply_effect(card_effect, eff_dur)
						RunManager.add_run_stat("effects_applied", 1.0)
				if enchant_attack_charges > 0 and enchant_effect != null and t.has_method("apply_effect"):
					t.apply_effect(enchant_effect, enchant_effect_durability)
					RunManager.add_run_stat("effects_applied", 1.0)
			if enchant_attack_charges > 0 and enchant_effect != null:
				enchant_attack_charges -= 1

			await _dash_to(player, player_anchor.global_position)
	elif card_effect != null and not targets.is_empty():
		for t in targets:
			if is_instance_valid(t) and t.has_method("apply_effect"):
				var eff_dur: int = max(1, card.get_effect_durability())
				t.apply_effect(card_effect, eff_dur)
				RunManager.add_run_stat("effects_applied", 1.0)

	var idx: int = hand.find(card)
	if idx != -1:
		hand.remove_at(idx)
	if card.get_exhaust():
		exhaust_pile.append(card)
	else:
		discard_pile.append(card)

	await _apply_post_play_manipulation(card)

	_refresh_hand_ui()
	_update_deck_ui()
	_update_ui()

	if _all_enemies_dead():
		_on_enemy_dead()
		return

	busy = false
	_set_buttons_enabled(true)


func _apply_post_play_manipulation(card: CardData) -> void:
	var discard_count: int = card.get_cards_to_discard_random()
	for _i in range(discard_count):
		if hand.is_empty():
			break
		var idx_discard: int = RunManager.rolli_range_run(0, hand.size() - 1)
		discard_pile.append(hand[idx_discard])
		hand.remove_at(idx_discard)

	var exhaust_count: int = card.get_cards_to_exhaust_random()
	for _i in range(exhaust_count):
		if hand.is_empty():
			break
		var idx_exhaust: int = RunManager.rolli_range_run(0, hand.size() - 1)
		exhaust_pile.append(hand[idx_exhaust])
		hand.remove_at(idx_exhaust)

	var draw_count: int = card.get_cards_to_draw()
	if draw_count > 0:
		await _draw_cards(draw_count)


func _on_enemy_dead() -> void:
	for enemy_instance in enemies:
		if is_instance_valid(enemy_instance):
			enemy_instance.queue_free()
	enemies.clear()

	var g_min: int = 10
	var g_max: int = 25
	if RunManager.current_enemy_data != null:
		g_min = int(RunManager.current_enemy_data.min_gold)
		g_max = int(RunManager.current_enemy_data.max_gold)
	var rolled_gold: int = RunManager.rolli_range_run(g_min, g_max)
	if RunManager.current_enemy_is_elite:
		rolled_gold = int(round(float(rolled_gold) * RunManager.elite_gold_multiplier))
	rolled_gold = int(round(float(rolled_gold) * RunManager.get_floor_gold_multiplier(RunManager.current_floor)))
	rolled_gold = max(1, rolled_gold)
	RunManager.pending_gold = rolled_gold
	if player_effects.has("regeneration"):
		var heal: int = _get_player_effect_value("regeneration")
		RunManager.current_hp = min(RunManager.max_hp, RunManager.current_hp + heal)
		RunManager.add_run_stat("healing_done", float(heal))
	player_effects.clear()
	RunManager.returning_from_fight = true
	RunManager.reward_claimed = false
	RunManager.add_run_stat("fights_won", 1.0)
	RunManager.add_run_stat("turns_spent", float(turn_number))
	_log_turn_action("System", "FightEnd", "Victory in %d turns, +%d gold" % [turn_number, rolled_gold])
	var fought_boss: bool = RunManager.current_enemy_data != null and RunManager.current_enemy_data.difficulty == EnemyData.Difficulty.BOSS
	if fought_boss or RunManager.current_floor >= RunManager.boss_floor:
		RunManager.on_boss_defeated()
		return
	get_tree().change_scene_to_file("res://level.tscn")


func _dash_to(actor: Node2D, target_pos: Vector2) -> void:
	var t: Tween = create_tween()
	t.tween_property(actor, "global_position", target_pos, dash_time)
	await t.finished


func _on_end_turn_pressed() -> void:
	if busy or not player_turn:
		return
	pending_target_card = null
	target_preview_enemy = null
	for card in hand:
		discard_pile.append(card)
	hand.clear()
	_refresh_hand_ui()
	_update_deck_ui()
	_set_buttons_enabled(false)

	await _tick_end_turn_effects()
	if _tick_player_effects(EffectData.TickWhen.END_TURN):
		return
	_update_ui()
	if _all_enemies_dead():
		_on_enemy_dead()
		return

	player_turn = false
	_start_turn()


func _tick_end_turn_effects() -> void:
	for enemy_instance in _get_alive_enemies():
		if enemy_instance.has_method("tick_end_turn_effects"):
			await enemy_instance.call("tick_end_turn_effects")


func _on_enemy_hit_player(_target: Node, source_enemy: Node2D) -> void:
	var dmg: int = 0
	if is_instance_valid(source_enemy):
		if source_enemy.has_method("get_effective_attack_damage"):
			dmg = int(source_enemy.get_effective_attack_damage())
		elif "damage" in source_enemy:
			dmg = int(source_enemy.damage)

	if _roll_player_miss_taken():
		dmg = 0

	var incoming_mult: float = _get_player_incoming_damage_multiplier()
	dmg = max(0, int(round(float(dmg) * incoming_mult)))

	var taken: int = max(0, dmg - player_defense)
	player_defense = max(0, player_defense - dmg)
	if player_effects.has("parry") and taken > 0 and is_instance_valid(source_enemy) and source_enemy.has_method("take_damage"):
		var prevented: int = int(round(float(taken) * 0.25))
		var reflect: int = prevented
		taken = max(0, taken - prevented)
		source_enemy.take_damage(reflect)
	if taken > 0:
		RunManager.current_hp = max(0, int(RunManager.current_hp) - taken)
		_spawn_damage_popup(_get_player_popup_position(), taken, true)
		RunManager.add_run_stat("damage_taken", float(taken))
		_log_turn_action("Enemy", "Attack", "Player took %d" % taken)
		if is_instance_valid(player) and player.has_method("play_take_damage"):
			player.call("play_take_damage")

	if int(RunManager.current_hp) <= 0:
		if RunManager.try_trigger_relic_revive():
			_update_ui()
			return
		RunManager.add_run_stat("fights_lost", 1.0)
		RunManager.finish_run(false, "Defeated in combat")
		return
	_update_ui()


func _input(event: InputEvent) -> void:
	if pending_target_card == null:
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		pending_target_card = null
		target_preview_enemy = null
		_update_ui()
		get_viewport().set_input_as_handled()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var picked: Node2D = _pick_enemy_from_screen_pos(mb.position)
	if picked == null:
		return
	var card_to_play: CardData = pending_target_card
	pending_target_card = null
	target_preview_enemy = null
	_update_ui()
	get_viewport().set_input_as_handled()
	await _play_card(card_to_play, picked)


func _should_request_target(card: CardData) -> bool:
	if card == null:
		return false
	if card.get_hits_all_enemies():
		return false
	if _get_alive_enemies().size() <= 1:
		return false
	return card.requires_target_selection()


func _set_target_prompt() -> void:
	if ui_enemy_intent != null and pending_target_card != null:
		ui_enemy_intent.text = "Choose target for: %s (RMB cancel)" % pending_target_card.get_display_title()


func _pick_enemy_from_screen_pos(_screen_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist: float = 999999.0
	var mouse_world: Vector2 = get_global_mouse_position()
	for e in _get_alive_enemies():
		if not is_instance_valid(e):
			continue
		var pick_pos: Vector2 = _get_enemy_pick_position(e)
		var d: float = pick_pos.distance_to(mouse_world)
		if d < best_dist:
			best_dist = d
			best = e
	if best_dist <= maxf(80.0, target_pick_radius):
		return best
	return null


func _get_enemy_pick_position(enemy_instance: Node2D) -> Vector2:
	if enemy_instance == null:
		return Vector2.ZERO
	var sprite: Node = enemy_instance.get_node_or_null("AnimatedSprite2D")
	if sprite != null and sprite is Node2D:
		return (sprite as Node2D).global_position
	return enemy_instance.global_position


func _process(_delta: float) -> void:
	_refresh_target_highlight()
	_refresh_damage_preview()


func _refresh_target_highlight() -> void:
	if pending_target_card == null:
		_clear_target_highlight()
		return
	var hovered: Node2D = _pick_enemy_from_screen_pos(Vector2.ZERO)
	target_preview_enemy = hovered
	for e in _get_alive_enemies():
		if not is_instance_valid(e):
			continue
		if e == hovered:
			e.modulate = Color(1.25, 1.25, 0.8, 1.0)
		else:
			e.modulate = Color(0.9, 0.9, 0.9, 1.0)


func _clear_target_highlight() -> void:
	if target_preview_enemy == null and pending_target_card == null:
		return
	target_preview_enemy = null
	for e in enemies:
		if is_instance_valid(e):
			e.modulate = Color.WHITE


func _refresh_damage_preview() -> void:
	if damage_preview_label == null:
		return
	if pending_target_card == null:
		damage_preview_label.visible = false
		return
	var card_damage: int = pending_target_card.get_damage()
	if card_damage <= 0:
		damage_preview_label.visible = false
		return
	var target: Node2D = target_preview_enemy
	if target == null:
		target = _get_primary_enemy()
	if target == null:
		damage_preview_label.visible = false
		return
	var outgoing_mult: float = _get_player_outgoing_damage_multiplier()
	var bonus: int = _get_player_effect_value("strength_surge")
	var predicted: int = max(0, int(round(float(card_damage + bonus) * outgoing_mult)))
	var target_name: String = "Enemy"
	if "data" in target and target.data != null:
		target_name = str(target.data.name)
	damage_preview_label.text = "Preview: %s will take %d" % [target_name, predicted]
	damage_preview_label.visible = true


func _get_player_popup_position() -> Vector2:
	if is_instance_valid(player):
		return player.global_position + Vector2(0.0, -72.0)
	return player_anchor.global_position + Vector2(0.0, -72.0)


func _spawn_damage_popup(world_pos: Vector2, value: int, is_damage: bool) -> void:
	var popup: Label = Label.new()
	popup.text = str(value)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_font_size_override("font_size", 28)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	popup.position = screen_pos + Vector2(randf_range(-18.0, 18.0), 0.0)
	popup.z_index = 200
	popup.modulate = Color(1.0, 0.25, 0.25, 1.0) if is_damage else Color(0.35, 1.0, 0.45, 1.0)
	ui_root.add_child(popup)

	var tween: Tween = popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - damage_popup_rise, damage_popup_duration)
	tween.tween_property(popup, "modulate:a", 0.0, damage_popup_duration)
	tween.finished.connect(popup.queue_free)


func _flash_label(label: Label) -> void:
	if label == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(label, "modulate", Color(1.0, 0.94, 0.58, 1.0), 0.09)
	tw.tween_property(label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)


func _roll_player_miss_taken() -> bool:
	var miss: int = _get_player_miss_chance_percent()
	if miss <= 0:
		return false
	return RunManager.rolli_range_run(1, 100) <= clampi(miss, 0, 95)


func _get_player_miss_chance_percent() -> int:
	var total: int = 0
	for id in player_effects.keys():
		var e: Dictionary = player_effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			continue
		total += max(0, eff.miss_chance_percent)
	return total


func _get_player_incoming_damage_multiplier() -> float:
	var mult: float = 1.0
	for id in player_effects.keys():
		var e: Dictionary = player_effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			continue
		mult *= eff.incoming_damage_multiplier
	return maxf(0.0, mult)


func _get_player_outgoing_damage_multiplier() -> float:
	var mult: float = 1.0
	for id in player_effects.keys():
		var e: Dictionary = player_effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			continue
		mult *= eff.outgoing_damage_multiplier
	return maxf(0.0, mult)


func _get_player_block_multiplier() -> float:
	var mult: float = 1.0
	for id in player_effects.keys():
		var e: Dictionary = player_effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			continue
		mult *= eff.block_gain_multiplier
	return maxf(0.0, mult)


func _on_enemy_apply_player_effects(payloads: Array) -> void:
	for payload_any in payloads:
		if typeof(payload_any) != TYPE_DICTIONARY:
			continue
		var payload: Dictionary = payload_any
		var effect: EffectData = payload.get("effect") as EffectData
		if effect == null:
			continue
		var dur: int = int(payload.get("duration", 1))
		var stacks: int = int(payload.get("stacks", 1))
		_apply_player_effect(effect, max(1, dur), max(1, stacks))
		RunManager.add_run_stat("effects_applied", 1.0)
		_log_turn_action("Enemy", "ApplyEffect", effect.title if effect.title != "" else effect.id)


func _on_enemy_damage_taken(amount: int, is_effect_damage: bool, source_enemy: Node2D) -> void:
	if amount <= 0:
		return
	var pos: Vector2 = _get_enemy_pick_position(source_enemy) + Vector2(0.0, -64.0)
	_spawn_damage_popup(pos, amount, true)
	RunManager.add_run_stat("damage_dealt", float(amount))
	if is_effect_damage:
		RunManager.add_run_stat("effect_damage", float(amount))
		_log_turn_action("Effect", "DamageOverTime", "Enemy took %d" % amount)
	else:
		_log_turn_action("Player", "Attack", "Enemy took %d" % amount)


func _enemy_action() -> void:
	var alive: Array[Node2D] = _get_alive_enemies()
	if alive.is_empty():
		player_turn = true
		return

	_update_ui()
	_log_turn_action("System", "TurnSwitch", "Enemy turn")
	for enemy_instance in alive:
		if not is_instance_valid(enemy_instance):
			continue
		if enemy_instance.has_method("take_turn"):
			await enemy_instance.call("take_turn", player, player_defense)
		elif enemy_instance.has_method("execute_turn"):
			await enemy_instance.call("execute_turn", player)

	if _all_enemies_dead():
		_on_enemy_dead()
		return

	player_turn = true
	busy = false
	_set_buttons_enabled(true)
	_update_ui()
	_start_turn()


func _set_buttons_enabled(enabled: bool) -> void:
	end_btn.disabled = not enabled


func _on_speed_pressed() -> void:
	RunManager.battle_speed_mult += 1
	if RunManager.battle_speed_mult > int(RunManager.battle_speed_max):
		RunManager.battle_speed_mult = int(RunManager.battle_speed_min)
	Engine.time_scale = float(RunManager.battle_speed_mult)
	if ui_speed_btn != null:
		ui_speed_btn.text = "x" + str(RunManager.battle_speed_mult)


func _on_deck_label_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_show_pile("Deck", draw_pile)


func _on_discard_label_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_show_pile("Discard", discard_pile)


func _on_exhaust_label_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_show_pile("Exhaust", exhaust_pile)


func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _show_pile(title: String, cards: Array[CardData]) -> void:
	if pile_overlay == null or pile_title_label == null or pile_cards_grid == null:
		return
	pile_title_label.text = "%s (%d)" % [title, cards.size()]
	_render_pile_cards(cards)
	pile_overlay.visible = true


func _hide_pile_overlay() -> void:
	if pile_overlay != null:
		pile_overlay.visible = false


func _render_pile_cards(cards: Array[CardData]) -> void:
	if pile_cards_grid == null:
		return
	for child in pile_cards_grid.get_children():
		child.queue_free()

	if cards.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "Empty"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 18)
		pile_cards_grid.add_child(empty_label)
		return

	for card in cards:
		if card == null:
			continue
		var card_view: CardView = card_view_scene.instantiate() as CardView
		if card_view == null:
			continue
		card_view.custom_minimum_size = Vector2(120, 160)
		card_view.use_physics = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_view.setup(card)
		pile_cards_grid.add_child(card_view)


func _apply_player_effect(effect: EffectData, durability: int, stacks: int = 1) -> void:
	if effect == null or effect.id == "":
		return
	var id: String = effect.id
	var e: Dictionary = player_effects.get(id, {})
	if e.is_empty():
		e = {"data": effect, "dur": durability, "stacks": max(1, stacks)}
	else:
		e["data"] = effect
		if effect.stackable:
			e["stacks"] = int(e.get("stacks", 0)) + max(1, stacks)
			e["dur"] = int(e.get("dur", 0)) + durability
		else:
			e["stacks"] = 1
			e["dur"] = max(int(e.get("dur", 0)), durability)
	player_effects[id] = e


func _tick_player_effects(phase: EffectData.TickWhen) -> bool:
	var to_remove: Array[String] = []
	for id in player_effects.keys():
		var e: Dictionary = player_effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			to_remove.append(id)
			continue
		if eff.tick_when != phase:
			continue

		if eff.is_damage_over_time:
			var stacks: int = int(e.get("stacks", 1))
			var dot: int = 0
			if eff.is_percent_of_current_hp_dot:
				dot = int(round(float(RunManager.current_hp) * (float(eff.value) / 100.0)))
			else:
				dot = max(0, int(eff.value) * max(1, stacks))
			if dot > 0:
				RunManager.current_hp = max(0, int(RunManager.current_hp) - dot)
				_spawn_damage_popup(_get_player_popup_position(), dot, true)
				RunManager.add_run_stat("damage_taken", float(dot))
				_log_turn_action("Effect", "DamageOverTime", "Player took %d" % dot)
				if int(RunManager.current_hp) <= 0:
					if RunManager.try_trigger_relic_revive():
						_update_ui()
					else:
						RunManager.add_run_stat("fights_lost", 1.0)
						RunManager.finish_run(false, "Defeated by effect damage")
					return true

		var dur: int = int(e.get("dur", 0))
		if dur > 0:
			dur -= 1
			e["dur"] = dur
			player_effects[id] = e
			if dur <= 0:
				to_remove.append(id)
	for rid in to_remove:
		player_effects.erase(rid)
	return false


func _refresh_player_effects_ui() -> void:
	if ui_player_status_row == null:
		return
	var sig: String = _build_effect_signature(_build_player_effect_details())
	if sig == player_status_signature:
		return
	player_status_signature = sig
	for c in ui_player_status_row.get_children():
		c.queue_free()
	if status_tooltip != null:
		status_tooltip.visible = false
	var details: Dictionary = _build_player_effect_details()
	for id in details.keys():
		var d: Dictionary = details[id]
		var l: Label = Label.new()
		var stacks: int = int(d.get("stacks", 1))
		var dur: int = int(d.get("duration", 0))
		var title: String = str(d.get("title", id))
		var desc: String = str(d.get("description", ""))
		l.text = "%s" % title
		if stacks > 1:
			l.text += " x%d" % stacks
		if dur > 0:
			l.text += " (%d)" % dur
		_bind_status_tooltip(l, title, desc)
		ui_player_status_row.add_child(l)


func _get_player_effect_value(effect_id: String) -> int:
	var e: Dictionary = player_effects.get(effect_id, {})
	if e.is_empty():
		return 0
	var eff: EffectData = e.get("data") as EffectData
	if eff == null:
		return 0
	return eff.value


func _build_player_effect_details() -> Dictionary:
	var out: Dictionary = {}
	for id in player_effects.keys():
		var e: Dictionary = player_effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			continue
		out[id] = {
			"title": eff.title if eff.title != "" else id,
			"description": eff.description,
			"stacks": int(e.get("stacks", 1)),
			"duration": int(e.get("dur", 0)),
		}
	return out


func _build_effect_signature(details: Dictionary) -> String:
	if details.is_empty():
		return "-"
	var keys: Array = details.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		var d: Dictionary = details[k]
		parts.append("%s|%s|%s" % [str(k), str(d.get("stacks", 0)), str(d.get("duration", 0))])
	return "||".join(parts)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
