extends CanvasLayer

const EVENT_DEFS: Array[Dictionary] = [
	{"id": "forgotten_shrine", "title": "Forgotten Shrine", "desc": "Pay HP for a rare card or cleanse a curse."},
	{"id": "cursed_totem", "title": "Cursed Totem", "desc": "Take a relic and receive a curse."},
	{"id": "traveling_sage", "title": "Traveling Sage", "desc": "Spend gold to upgrade cards or cleanse curses."},
]

@onready var cards_list: VBoxContainer = $Root/Panel/Margin/Content/Tabs/Cards/Scroll/List
@onready var relics_list: VBoxContainer = $Root/Panel/Margin/Content/Tabs/Relics/Scroll/List
@onready var enemies_list: VBoxContainer = $Root/Panel/Margin/Content/Tabs/Enemies/Scroll/List
@onready var events_list: VBoxContainer = $Root/Panel/Margin/Content/Tabs/Events/Scroll/List
@onready var history_list: VBoxContainer = $Root/Panel/Margin/Content/Tabs/History/Scroll/List
@onready var level_label: Label = $Root/Panel/Margin/Content/TopRow/ProfilePanel/ProfileMargin/ProfileVBox/LevelLabel
@onready var xp_label: Label = $Root/Panel/Margin/Content/TopRow/ProfilePanel/ProfileMargin/ProfileVBox/XPLabel
@onready var next_unlock_label: Label = $Root/Panel/Margin/Content/TopRow/ProfilePanel/ProfileMargin/ProfileVBox/NextUnlockLabel
@onready var show_known_only_checkbox: CheckBox = $Root/Panel/Margin/Content/TopRow/FilterBox/FilterMargin/ShowKnownOnly

var show_known_only: bool = false


func _ready() -> void:
	if show_known_only_checkbox != null:
		show_known_only_checkbox.toggled.connect(_on_show_known_only_toggled)
	_refresh_profile_block()
	_refresh_all_lists()


func _on_show_known_only_toggled(pressed: bool) -> void:
	show_known_only = pressed
	_refresh_all_lists()


func _refresh_all_lists() -> void:
	_fill_cards()
	_fill_relics()
	_fill_enemies()
	_fill_events()
	_fill_history()


func _refresh_profile_block() -> void:
	var level: int = 1
	var xp_in_level: int = 0
	var xp_to_next: int = 0
	if has_node("/root/MetaProgression"):
		var meta: Node = get_node("/root/MetaProgression")
		level = int(meta.get("player_level"))
		xp_in_level = int(meta.get("current_xp"))
		if meta.has_method("xp_to_next_level"):
			xp_to_next = int(meta.call("xp_to_next_level", level))

	level_label.text = "Level: %d" % level
	xp_label.text = "XP: %d / %d" % [xp_in_level, xp_to_next]

	var next_unlocks: Dictionary = _get_next_unlocks(level)
	var unlock_level: int = int(next_unlocks.get("level", 0))
	var entries: PackedStringArray = next_unlocks.get("entries", PackedStringArray())
	if unlock_level <= 0 or entries.is_empty():
		next_unlock_label.text = "Next unlock: all known unlock tiers reached"
	else:
		next_unlock_label.text = "Next unlock (Lvl %d): %s" % [unlock_level, ", ".join(entries)]


func _fill_cards() -> void:
	_clear_list(cards_list)
	var cards: Array[CardData] = []
	var raw_cards: Array = RunManager._load_resources_recursive("res://Cards/Data", "tres", "CardData")
	for item in raw_cards:
		if item is CardData:
			cards.append(item as CardData)
	cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.id < b.id
	)
	for card in cards:
		if card == null:
			continue
		var seen: bool = _meta_bool("is_card_seen", card.id)
		var unlocked: bool = _meta_call("is_card_unlocked", card)
		if show_known_only and not seen:
			continue
		var req_level: int = _meta_int("get_card_unlock_level", card, card.unlock_level)
		var status: String = "Lvl %d | %s | %s" % [req_level, card.get_rarity_name(), ("Unlocked" if unlocked else "Locked")]
		_add_entry(cards_list, card.title if seen else "Unknown Card", (card.description if seen else "???") + "\n" + status, seen)


func _fill_relics() -> void:
	_clear_list(relics_list)
	var relics: Array[RelicData] = []
	var raw_relics: Array = RunManager._load_resources_recursive("res://Relic/Data", "tres", "RelicData")
	for item in raw_relics:
		if item is RelicData:
			relics.append(item as RelicData)
	relics.sort_custom(func(a: RelicData, b: RelicData) -> bool:
		return a.id < b.id
	)
	for relic in relics:
		if relic == null:
			continue
		var seen: bool = _meta_bool("is_relic_seen", relic.id)
		var unlocked: bool = _meta_call("is_relic_unlocked", relic)
		if show_known_only and not seen:
			continue
		var req_level: int = _meta_int("get_relic_unlock_level", relic, relic.unlock_level)
		var status: String = "Lvl %d | %s" % [req_level, ("Unlocked" if unlocked else "Locked")]
		_add_entry(relics_list, relic.get_display_name() if seen else "Unknown Relic", (relic.description if seen else "???") + "\n" + status, seen)


func _fill_enemies() -> void:
	_clear_list(enemies_list)
	var filtered: Array[EnemyData] = _load_enemy_resources()
	filtered.sort_custom(func(a: EnemyData, b: EnemyData) -> bool:
		return a.name < b.name
	)
	for enemy in filtered:
		var seen: bool = _meta_bool("is_enemy_seen", enemy.resource_path)
		if show_known_only and not seen:
			continue
		var diff: String = "Normal"
		if enemy.difficulty == EnemyData.Difficulty.ELITE:
			diff = "Elite"
		elif enemy.difficulty == EnemyData.Difficulty.BOSS:
			diff = "Boss"
		var intents: PackedStringArray = PackedStringArray()
		for action in enemy.battle_actions:
			var a: int = int(action)
			match a:
				EnemyData.Intent.ATTACK:
					intents.append("ATTACK")
				EnemyData.Intent.DEFEND:
					intents.append("DEFEND")
				EnemyData.Intent.BUFF:
					intents.append("BUFF")
				EnemyData.Intent.DEBUFF:
					intents.append("DEBUFF")
		var desc: String = "Difficulty: %s\nBase HP: %d\nBase Damage: %d\nActions: %s" % [diff, enemy.base_hp, enemy.base_damage, ", ".join(intents)]
		_add_entry(enemies_list, enemy.name if seen else "Unknown Enemy", desc if seen else "???", seen)


func _fill_events() -> void:
	_clear_list(events_list)
	for ev in EVENT_DEFS:
		var id: String = str(ev.get("id", ""))
		var seen: bool = _meta_bool("is_event_seen", id)
		if show_known_only and not seen:
			continue
		_add_entry(events_list, str(ev.get("title", "Event")) if seen else "Unknown Event", str(ev.get("desc", "???")) if seen else "???", seen)


func _fill_history() -> void:
	_clear_list(history_list)
	var save_node: Node = get_node_or_null("/root/SaveSystem")
	if save_node == null or not save_node.has_method("get_run_history"):
		_add_entry(history_list, "Run History", "Unavailable", true)
		return
	var rows_variant: Variant = save_node.call("get_run_history", 30)
	if not (rows_variant is Array):
		_add_entry(history_list, "Run History", "No data", true)
		return
	var rows: Array = rows_variant
	if rows.is_empty():
		_add_entry(history_list, "Run History", "No runs yet", true)
		return
	for i in range(rows.size() - 1, -1, -1):
		var row_any: Variant = rows[i]
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		var victory: bool = bool(row.get("victory", false))
		var floor_reached: int = int(row.get("floor_reached", 0))
		var xp_gain: int = int(row.get("xp_gain", 0))
		var seed_value: int = int(row.get("run_seed", 0))
		var reason: String = str(row.get("reason", "-"))
		var stats: Dictionary = row.get("stats", {}) as Dictionary
		var turns: int = int(round(float(stats.get("turns_spent", 0.0))))
		var fights: int = int(round(float(stats.get("fights_won", 0.0))))
		var title: String = ("Victory" if victory else "Defeat") + " | Floor " + str(floor_reached)
		var desc: String = "Reason: %s\nXP: %d | Fights: %d | Turns: %d | Seed: %d" % [reason, xp_gain, fights, turns, seed_value]
		_add_entry(history_list, title, desc, true)


func _add_entry(parent: VBoxContainer, title: String, desc: String, known: bool) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 84.0)
	parent.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	margin.add_child(v)

	var t: Label = Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	v.add_child(t)

	var d: Label = Label.new()
	d.text = desc
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)

	if not known:
		panel.modulate = Color(0.2, 0.2, 0.2, 0.95)


func _clear_list(list: VBoxContainer) -> void:
	for c in list.get_children():
		c.queue_free()


func _load_enemy_resources() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	var stack: Array[String] = ["res://Enemies"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.begins_with("."):
				file_name = dir.get_next()
				continue
			var full: String = dir_path.path_join(file_name)
			if dir.current_is_dir():
				stack.append(full)
			elif file_name.get_extension().to_lower() == "tres":
				var res: Resource = load(full)
				if res is EnemyData:
					out.append(res as EnemyData)
			file_name = dir.get_next()
		dir.list_dir_end()
	return out


func _meta_bool(method_name: String, id: String) -> bool:
	var meta: Node = get_node_or_null("/root/MetaProgression")
	if meta == null:
		return false
	if not meta.has_method(method_name):
		return false
	return bool(meta.call(method_name, id))


func _meta_call(method_name: String, arg: Variant) -> bool:
	var meta: Node = get_node_or_null("/root/MetaProgression")
	if meta == null:
		return true
	if not meta.has_method(method_name):
		return true
	return bool(meta.call(method_name, arg))


func _meta_int(method_name: String, arg: Variant, fallback: int) -> int:
	var meta: Node = get_node_or_null("/root/MetaProgression")
	if meta == null:
		return fallback
	if not meta.has_method(method_name):
		return fallback
	return int(meta.call(method_name, arg))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")


func _get_next_unlocks(current_level: int) -> Dictionary:
	var card_rows: Array[Dictionary] = []
	var relic_rows: Array[Dictionary] = []

	var raw_cards: Array = RunManager._load_resources_recursive("res://Cards/Data", "tres", "CardData")
	for item in raw_cards:
		if item is CardData:
			var c: CardData = item as CardData
			card_rows.append({
				"level": _meta_int("get_card_unlock_level", c, c.unlock_level),
				"name": c.title if c.title != "" else c.id,
			})

	var raw_relics: Array = RunManager._load_resources_recursive("res://Relic/Data", "tres", "RelicData")
	for item in raw_relics:
		if item is RelicData:
			var r: RelicData = item as RelicData
			relic_rows.append({
				"level": _meta_int("get_relic_unlock_level", r, r.unlock_level),
				"name": r.get_display_name(),
			})

	var next_level: int = 9999
	for row in card_rows:
		var lvl: int = int(row.get("level", 1))
		if lvl > current_level and lvl < next_level:
			next_level = lvl
	for row in relic_rows:
		var lvl: int = int(row.get("level", 1))
		if lvl > current_level and lvl < next_level:
			next_level = lvl

	if next_level == 9999:
		return {"level": 0, "entries": PackedStringArray()}

	var names: PackedStringArray = PackedStringArray()
	for row in card_rows:
		if int(row.get("level", 1)) == next_level:
			names.append("Card: " + str(row.get("name", "")))
	for row in relic_rows:
		if int(row.get("level", 1)) == next_level:
			names.append("Relic: " + str(row.get("name", "")))

	var limited: PackedStringArray = PackedStringArray()
	for i in range(mini(8, names.size())):
		limited.append(names[i])
	if names.size() > 8:
		limited.append("...")
	return {"level": next_level, "entries": limited}
