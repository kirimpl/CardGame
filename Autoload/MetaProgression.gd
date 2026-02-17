extends Node

const PROFILE_PATH: String = "user://meta_profile.json"
const RUN_SAVE_PATH: String = "user://run_save.json"
const CARD_UNLOCK_OVERRIDES: Dictionary = {
	"strike": 1, "shield": 1, "slash": 1, "guard_up": 1, "ember_cut": 1,
	"quick_slash": 2, "heavy_slash": 2, "twin_cut": 2, "whirlwind": 2, "smoke_screen": 2,
	"deep_focus": 3, "steel_rain": 3, "flame_oil": 3, "blazing_strike": 3, "stunning_blow": 3,
	"iron_wall": 4, "parry_stance": 4, "expose_weakness": 4, "shatter_armor": 4, "counter_stance": 4,
	"inferno_edge": 5, "night_ritual": 5, "enchanted_sword": 5, "power_surge": 5, "intercept_mark": 5,
}
const RELIC_UNLOCK_OVERRIDES: Dictionary = {
	"vital_core": 1, "sunlit_flask": 1, "phoenix_feather": 1,
	"cheap_ledger": 2, "field_rations": 2, "hex_prism": 2,
	"haggle_charm": 3, "ember_idol": 3, "oil_catalyst": 3,
	"night_fang": 4, "tempered_tongs": 4, "master_stamp": 4,
	"venom_lens": 5, "warden_band": 5, "lunar_emblem": 5,
}

@export var level_xp_base: int = 120
@export var level_xp_growth: float = 1.22

var player_level: int = 1
var current_xp: int = 0
var total_xp: int = 0
var runs_completed: int = 0
var seen_cards: Dictionary = {}
var seen_relics: Dictionary = {}
var seen_enemies: Dictionary = {}
var seen_events: Dictionary = {}


func _ready() -> void:
	load_profile()
	_try_merge_from_run_save()


func xp_to_next_level(level: int = player_level) -> int:
	var lvl: int = max(1, level)
	return int(round(float(level_xp_base) * pow(level_xp_growth, float(lvl - 1))))


func add_xp(amount: int) -> Dictionary:
	var gained: int = max(0, amount)
	current_xp += gained
	total_xp += gained
	runs_completed += 1

	var levels_gained: int = 0
	while current_xp >= xp_to_next_level(player_level):
		current_xp -= xp_to_next_level(player_level)
		player_level += 1
		levels_gained += 1

	save_profile()
	return {
		"gained_xp": gained,
		"levels_gained": levels_gained,
		"new_level": player_level,
		"xp_in_level": current_xp,
		"xp_to_next": xp_to_next_level(player_level),
	}


func is_card_unlocked(card: CardData) -> bool:
	if card == null:
		return false
	return player_level >= get_card_unlock_level(card)


func is_relic_unlocked(relic: RelicData) -> bool:
	if relic == null:
		return false
	return player_level >= get_relic_unlock_level(relic)


func get_card_unlock_level(card: CardData) -> int:
	if card == null:
		return 1
	if CARD_UNLOCK_OVERRIDES.has(card.id):
		return int(CARD_UNLOCK_OVERRIDES[card.id])
	return max(1, card.unlock_level)


func get_relic_unlock_level(relic: RelicData) -> int:
	if relic == null:
		return 1
	if RELIC_UNLOCK_OVERRIDES.has(relic.id):
		return int(RELIC_UNLOCK_OVERRIDES[relic.id])
	return max(1, relic.unlock_level)


func mark_card_seen(card_id: String) -> void:
	var id: String = card_id.strip_edges()
	if id == "":
		return
	if seen_cards.has(id):
		return
	seen_cards[id] = true
	save_profile()


func mark_relic_seen(relic_id: String) -> void:
	var id: String = relic_id.strip_edges()
	if id == "":
		return
	if seen_relics.has(id):
		return
	seen_relics[id] = true
	save_profile()


func mark_enemy_seen(enemy_id: String) -> void:
	var id: String = enemy_id.strip_edges()
	if id == "":
		return
	if seen_enemies.has(id):
		return
	seen_enemies[id] = true
	save_profile()


func mark_event_seen(event_id: String) -> void:
	var id: String = event_id.strip_edges()
	if id == "":
		return
	if seen_events.has(id):
		return
	seen_events[id] = true
	save_profile()


func is_card_seen(card_id: String) -> bool:
	return seen_cards.has(card_id)


func is_relic_seen(relic_id: String) -> bool:
	return seen_relics.has(relic_id)


func is_enemy_seen(enemy_id: String) -> bool:
	return seen_enemies.has(enemy_id)


func is_event_seen(event_id: String) -> bool:
	return seen_events.has(event_id)


func load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		save_profile()
		return
	var f: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	player_level = max(1, int(d.get("player_level", 1)))
	current_xp = max(0, int(d.get("current_xp", 0)))
	total_xp = max(0, int(d.get("total_xp", 0)))
	runs_completed = max(0, int(d.get("runs_completed", 0)))
	seen_cards = _arr_to_set(d.get("seen_cards", []))
	seen_relics = _arr_to_set(d.get("seen_relics", []))
	seen_enemies = _arr_to_set(d.get("seen_enemies", []))
	seen_events = _arr_to_set(d.get("seen_events", []))


func save_profile() -> void:
	var d: Dictionary = {
		"player_level": player_level,
		"current_xp": current_xp,
		"total_xp": total_xp,
		"runs_completed": runs_completed,
		"seen_cards": seen_cards.keys(),
		"seen_relics": seen_relics.keys(),
		"seen_enemies": seen_enemies.keys(),
		"seen_events": seen_events.keys(),
	}
	var f: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.flush()
	f.close()


func _arr_to_set(arr_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if arr_any is Array:
		for v in arr_any:
			out[str(v)] = true
	return out


func _try_merge_from_run_save() -> void:
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(RUN_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = parsed
	var meta_any: Variant = payload.get("meta_state", {})
	if typeof(meta_any) == TYPE_DICTIONARY:
		import_state_merge(meta_any as Dictionary)
		return

	var run_any: Variant = payload.get("run_state", {})
	if typeof(run_any) != TYPE_DICTIONARY:
		return
	var run_state: Dictionary = run_any as Dictionary
	var deck_any: Variant = run_state.get("deck", [])
	if deck_any is Array:
		for item_any in deck_any:
			if typeof(item_any) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = item_any
			var cid: String = str(item.get("id", ""))
			if cid != "":
				seen_cards[cid] = true
	var relic_any: Variant = run_state.get("relics", [])
	if relic_any is Array:
		for item_any in relic_any:
			if typeof(item_any) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = item_any
			var rid: String = str(item.get("id", ""))
			if rid != "":
				seen_relics[rid] = true
	save_profile()


func export_state() -> Dictionary:
	return {
		"player_level": player_level,
		"current_xp": current_xp,
		"total_xp": total_xp,
		"runs_completed": runs_completed,
		"seen_cards": seen_cards.keys(),
		"seen_relics": seen_relics.keys(),
		"seen_enemies": seen_enemies.keys(),
		"seen_events": seen_events.keys(),
	}


func import_state_merge(data: Dictionary) -> void:
	if data.is_empty():
		return
	player_level = max(1, max(player_level, int(data.get("player_level", player_level))))
	current_xp = max(current_xp, int(data.get("current_xp", current_xp)))
	total_xp = max(total_xp, int(data.get("total_xp", total_xp)))
	runs_completed = max(runs_completed, int(data.get("runs_completed", runs_completed)))

	var cards: Dictionary = _arr_to_set(data.get("seen_cards", []))
	for k in cards.keys():
		seen_cards[str(k)] = true
	var relics_dict: Dictionary = _arr_to_set(data.get("seen_relics", []))
	for k in relics_dict.keys():
		seen_relics[str(k)] = true
	var enemies_dict: Dictionary = _arr_to_set(data.get("seen_enemies", []))
	for k in enemies_dict.keys():
		seen_enemies[str(k)] = true
	var events_dict: Dictionary = _arr_to_set(data.get("seen_events", []))
	for k in events_dict.keys():
		seen_events[str(k)] = true

	save_profile()
