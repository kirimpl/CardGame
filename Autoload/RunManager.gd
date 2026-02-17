extends Node

const ROOM_ENEMY: String = "ENEMY"
const ROOM_ELITE: String = "ELITE"
const ROOM_REST: String = "REST"
const ROOM_EVENT: String = "EVENT"
const ROOM_TREASURE: String = "TREASURE"
const ROOM_MERCHANT: String = "MERCHANT"
const ROOM_BOSS: String = "BOSS"

@export_group("Run Defaults")
@export var start_floor: int = 1
@export var start_act: int = 1
@export var start_gold: int = 15
@export var base_max_hp: int = 88
@export_range(1, 20, 1) var battle_speed_min: int = 1
@export_range(1, 20, 1) var battle_speed_max: int = 5
@export_range(1, 100, 1) var floors_per_act: int = 9
@export_range(1, 100, 1) var boss_floor: int = 10
@export_range(1, 10, 1) var total_acts: int = 3
@export_range(1.0, 5.0, 0.1) var final_victory_xp_multiplier: float = 2.0
@export_range(0.0, 1.0, 0.01) var elite_chance: float = 0.17
@export_range(1.0, 5.0, 0.05) var elite_gold_multiplier: float = 1.65
@export_range(0.5, 1.5, 0.01) var early_floor_gold_multiplier: float = 0.85
@export_range(0.5, 1.5, 0.01) var mid_floor_gold_multiplier: float = 0.93
@export_range(0.0, 1.0, 0.01) var multi_enemy_chance: float = 0.30
@export_range(2, 4, 1) var multi_enemy_max_count: int = 2
@export var starting_relics: Array[RelicData] = []
@export var guaranteed_rest_floors: PackedInt32Array = PackedInt32Array([5, 9])
@export_file("*.tscn") var level_scene_path: String = "res://level.tscn"
@export_file("*.tscn") var rest_room_scene_path: String = "res://level.tscn"
@export_range(0.0, 1.0, 0.01) var campfire_heal_percent: float = 0.40
@export_range(1.0, 3.0, 0.05) var night_enemy_hp_multiplier: float = 1.15
@export_range(1.0, 3.0, 0.05) var night_enemy_damage_multiplier: float = 1.10
@export_file("*.tscn") var map_scene_path: String = "res://UI/map_screen.tscn"
@export_file("*.tscn") var run_result_scene_path: String = "res://UI/run_result.tscn"
@export_range(2, 6, 1) var map_lane_count: int = 3
@export_range(1, 3, 1) var map_branch_width: int = 1
@export var fixed_seed: int = 0

var current_floor: int = 1
var current_act: int = 1
var gold: int = 0
var pending_gold: int = 0
var battle_speed_mult: int = 1
var max_hp: int = 96
var current_hp: int = 100
var current_enemy_data: EnemyData = null
var current_enemy_is_elite: bool = false
var returning_from_fight: bool = false
var reward_claimed: bool = false
var deck: Array[CardData] = []
var relics: Array[RelicData] = []
var consumed_one_shot_relic_indices: Dictionary = {}
var used_smith_free_upgrades: int = 0
var merchant_purge_count: int = 0
var is_night: bool = false
var forced_room_type: String = ""
var map_nodes: Dictionary = {}
var map_edges: Array[Dictionary] = []
var map_lane_profiles: Dictionary = {}
var map_generated_act: int = -1
var current_map_lane: int = 1
var combat_log: Array[String] = []
var combat_events: Array[Dictionary] = []
var replay_events: Array[Dictionary] = []
var run_seed: int = 0
var rng_state: int = 0
var run_stats: Dictionary = {}
var last_run_summary: Dictionary = {}

var normal_enemies: Array[EnemyData] = []
var elite_enemies: Array[EnemyData] = []
var boss_enemies: Array[EnemyData] = []
var all_cards_cache: Array[CardData] = []
var all_relics_cache: Array[RelicData] = []
var loaded_enemy_act: int = -1

func _ready() -> void:
	_randomize_once()
	start_new_run()
	_load_enemy_pools()
	_load_content_pools()


func _randomize_once() -> void:
	if Engine.get_frames_drawn() == 0:
		randomize()


func _init_rng(seed_value: int) -> void:
	run_seed = seed_value
	seed(seed_value)
	rng_state = seed_value


func set_run_seed(seed_value: int) -> void:
	_init_rng(seed_value)


func get_run_seed() -> int:
	return run_seed


func _rollf() -> float:
	var v: float = randf()
	rng_state = randi()
	return v


func _rollf_range(from_value: float, to_value: float) -> float:
	var v: float = randf_range(from_value, to_value)
	rng_state = randi()
	return v


func _rolli_range(from_value: int, to_value: int) -> int:
	var v: int = randi_range(from_value, to_value)
	rng_state = randi()
	return v


func _pick_index(count: int) -> int:
	if count <= 0:
		return -1
	return _rolli_range(0, count - 1)


func rollf_run() -> float:
	return _rollf()


func rolli_range_run(from_value: int, to_value: int) -> int:
	return _rolli_range(from_value, to_value)


func pick_from_array_run(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_pick_index(items.size())]


func _load_enemy_pools() -> void:
	loaded_enemy_act = current_act
	normal_enemies.clear()
	elite_enemies.clear()
	boss_enemies.clear()

	var enemy_root: String = _get_enemy_root_for_act(current_act)
	var stack: Array[String] = [enemy_root]
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
					_match_and_add_enemy(res as EnemyData)
			file_name = dir.get_next()
		dir.list_dir_end()


func _get_enemy_root_for_act(act: int) -> String:
	var act_root: String = "res://Enemies/Act%d" % act
	var dir: DirAccess = DirAccess.open(act_root)
	if dir != null:
		return act_root
	return "res://Enemies"


func _ensure_enemy_pools_for_current_act() -> void:
	if loaded_enemy_act != current_act:
		_load_enemy_pools()


func _load_content_pools() -> void:
	all_cards_cache.clear()
	all_relics_cache.clear()

	var card_resources: Array = _load_resources_recursive("res://Cards/Data", "tres", "CardData")
	for res in card_resources:
		if res is CardData:
			all_cards_cache.append(res as CardData)

	var relic_resources: Array = _load_resources_recursive("res://Relic/Data", "tres", "RelicData")
	for res in relic_resources:
		if res is RelicData:
			var relic: RelicData = res as RelicData
			if relic.id.strip_edges() == "":
				continue
			if relic.is_starter_relic:
				continue
			all_relics_cache.append(relic)


func _load_resources_recursive(root_path: String, extension: String, class_name_hint: String) -> Array:
	var out: Array = []
	var stack: Array[String] = [root_path]
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
			elif file_name.get_extension().to_lower() == extension:
				var res: Resource = load(full)
				if res == null:
					file_name = dir.get_next()
					continue
				if class_name_hint == "CardData" and res is CardData:
					out.append(res)
				elif class_name_hint == "RelicData" and res is RelicData:
					out.append(res)
			file_name = dir.get_next()
		dir.list_dir_end()
	return out


func _match_and_add_enemy(e: EnemyData) -> void:
	match e.difficulty:
		EnemyData.Difficulty.ELITE:
			elite_enemies.append(e)
		EnemyData.Difficulty.BOSS:
			boss_enemies.append(e)
		_:
			normal_enemies.append(e)


func pick_enemy_for_floor() -> EnemyData:
	_ensure_enemy_pools_for_current_act()
	var diff: String = get_enemy_difficulty()
	var pool: Array[EnemyData] = []
	match diff:
		"ELITE":
			pool = elite_enemies
		"BOSS":
			pool = boss_enemies
		_:
			pool = normal_enemies

	if pool.is_empty():
		pool = normal_enemies
	if pool.is_empty():
		pool = elite_enemies
	if pool.is_empty():
		pool = boss_enemies
	if pool.is_empty():
		return null

	var idx: int = _pick_index(pool.size())
	current_enemy_data = null
	if idx >= 0:
		current_enemy_data = pool[idx]
	current_enemy_is_elite = (diff == "ELITE")
	return current_enemy_data


func get_fight_enemy_count() -> int:
	if current_enemy_data == null:
		return 1
	if current_enemy_data.difficulty == EnemyData.Difficulty.BOSS:
		return 1
	if multi_enemy_max_count < 2:
		return 1
	if _rollf() >= multi_enemy_chance:
		return 1
	return _rolli_range(2, multi_enemy_max_count)


func start_new_run() -> void:
	var seed_value: int = fixed_seed if fixed_seed != 0 else int(Time.get_unix_time_from_system()) + int(randi())
	_init_rng(seed_value)
	current_floor = start_floor
	current_act = start_act
	gold = start_gold
	max_hp = base_max_hp
	current_hp = max_hp
	current_enemy_data = null
	battle_speed_mult = clampi(battle_speed_mult, battle_speed_min, battle_speed_max)
	current_enemy_is_elite = false
	returning_from_fight = false
	reward_claimed = false
	is_night = false
	deck.clear()
	relics.clear()
	consumed_one_shot_relic_indices.clear()
	used_smith_free_upgrades = 0
	merchant_purge_count = 0
	forced_room_type = ""
	map_nodes.clear()
	map_edges.clear()
	map_lane_profiles.clear()
	map_generated_act = -1
	current_map_lane = clampi(current_map_lane, 0, max(0, map_lane_count - 1))
	combat_log.clear()
	combat_events.clear()
	replay_events.clear()
	last_run_summary.clear()
	run_stats = {
		"fights_won": 0,
		"fights_lost": 0,
		"turns_spent": 0,
		"effects_applied": 0,
		"effect_damage": 0,
		"healing_done": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
	}
	bootstrap_starting_relics_from_fight_scene()
	apply_starting_relics()
	log_combat("Run started. Floor %d" % current_floor)
	record_replay_event("run_start", {"seed": run_seed, "floor": current_floor, "act": current_act})


func next_floor() -> void:
	if current_floor >= boss_floor:
		finish_run(true, "Boss defeated")
		return
	get_tree().call_deferred("change_scene_to_file", map_scene_path)


func is_rest_floor(floor: int) -> bool:
	return guaranteed_rest_floors.has(floor)


func get_scene_for_floor(floor: int) -> String:
	if forced_room_type == ROOM_REST:
		return rest_room_scene_path
	if forced_room_type == ROOM_BOSS:
		return level_scene_path
	if is_rest_floor(floor):
		return rest_room_scene_path
	return level_scene_path


func get_enemy_difficulty() -> String:
	if forced_room_type == ROOM_ELITE:
		return "ELITE"
	if forced_room_type == ROOM_BOSS:
		return "BOSS"
	if forced_room_type == ROOM_ENEMY:
		return "NORMAL"
	if current_floor <= 2:
		return "NORMAL"
	if current_floor == boss_floor:
		return "BOSS"
	if _rollf() < elite_chance:
		return "ELITE"
	return "NORMAL"


func toggle_day_night() -> void:
	is_night = not is_night
	_recalculate_derived_stats()
	record_replay_event("time_toggle", {"is_night": is_night})


func log_combat(entry: String) -> void:
	var text: String = entry.strip_edges()
	if text == "":
		return
	combat_log.append(text)
	if combat_log.size() > 180:
		combat_log.remove_at(0)


func log_combat_event(category: String, actor: String, action: String, result: String, turn: int = 0) -> void:
	var event: Dictionary = {
		"turn": max(0, turn),
		"category": category.strip_edges().to_upper(),
		"actor": actor.strip_edges(),
		"action": action.strip_edges(),
		"result": result.strip_edges(),
	}
	combat_events.append(event)
	if combat_events.size() > 260:
		combat_events.remove_at(0)

	var line: String = "Turn %d | %s | %s | %s" % [max(0, turn), event["actor"], event["action"], event["result"]]
	log_combat(line)
	record_replay_event("combat", event)


func get_combat_events_tail(max_entries: int = 40, category_filter: String = "ALL") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wanted: String = category_filter.strip_edges().to_upper()
	var count: int = clampi(max_entries, 1, 260)
	for i in range(combat_events.size() - 1, -1, -1):
		var ev: Dictionary = combat_events[i]
		var cat: String = str(ev.get("category", "SYSTEM")).to_upper()
		if wanted != "" and wanted != "ALL" and wanted != cat:
			continue
		out.push_front(ev)
		if out.size() >= count:
			break
	return out


func record_replay_event(event_type: String, payload: Dictionary = {}) -> void:
	var event: Dictionary = {
		"ts_ms": Time.get_ticks_msec(),
		"floor": current_floor,
		"act": current_act,
		"type": event_type.strip_edges().to_lower(),
		"payload": payload.duplicate(true),
	}
	replay_events.append(event)
	if replay_events.size() > 1800:
		replay_events.remove_at(0)


func get_replay_events_tail(max_entries: int = 120) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var count: int = clampi(max_entries, 1, 1800)
	var start_idx: int = max(0, replay_events.size() - count)
	for i in range(start_idx, replay_events.size()):
		out.append(replay_events[i])
	return out


func get_combat_log_tail(max_entries: int = 40) -> PackedStringArray:
	var count: int = clampi(max_entries, 1, 180)
	var out: PackedStringArray = PackedStringArray()
	var start_idx: int = max(0, combat_log.size() - count)
	for i in range(start_idx, combat_log.size()):
		out.append(combat_log[i])
	return out


func add_run_stat(key: String, delta: float) -> void:
	var prev: float = float(run_stats.get(key, 0.0))
	run_stats[key] = prev + delta


func build_floor_map_nodes(floor: int) -> Array[Dictionary]:
	_ensure_map_generated()
	if map_nodes.has(floor):
		return map_nodes[floor]
	return []


func get_map_edges() -> Array[Dictionary]:
	_ensure_map_generated()
	return map_edges


func get_reachable_lanes_for_floor(floor: int) -> PackedInt32Array:
	_ensure_map_generated()
	var lanes: PackedInt32Array = PackedInt32Array()
	if floor != current_floor + 1:
		return lanes
	for edge in map_edges:
		if int(edge.get("from_floor", -1)) != current_floor:
			continue
		if int(edge.get("from_lane", -1)) != current_map_lane:
			continue
		if int(edge.get("to_floor", -1)) != floor:
			continue
		var to_lane: int = int(edge.get("to_lane", -1))
		if to_lane >= 0 and not lanes.has(to_lane):
			lanes.append(to_lane)
	if lanes.is_empty():
		var nodes: Array[Dictionary] = build_floor_map_nodes(floor)
		for n in nodes:
			var lane: int = int(n.get("lane", -1))
			if lane >= 0:
				lanes.append(lane)
	return lanes


func travel_to_room(floor: int, lane: int, room_type: String) -> void:
	_ensure_map_generated()
	if floor != current_floor + 1:
		return
	if not get_reachable_lanes_for_floor(floor).has(lane):
		return
	current_floor = floor
	current_map_lane = clampi(lane, 0, max(0, map_lane_count - 1))
	forced_room_type = room_type
	current_enemy_is_elite = (room_type == ROOM_ELITE)
	returning_from_fight = false
	reward_claimed = false
	log_combat("Travel: floor %d -> %s" % [current_floor, room_type])
	record_replay_event("travel", {"floor": floor, "lane": lane, "room_type": room_type})
	get_tree().call_deferred("change_scene_to_file", get_scene_for_floor(current_floor))


func consume_forced_room_type() -> String:
	var out: String = forced_room_type
	forced_room_type = ""
	return out


func _roll_room_type_for_floor(floor: int, lane: int) -> String:
	if floor >= boss_floor:
		return ROOM_BOSS
	if is_rest_floor(floor):
		return ROOM_REST

	var profile: String = str(map_lane_profiles.get(lane, "combat"))
	var weights: Dictionary = {}
	match profile:
		"elite":
			weights = {ROOM_ENEMY: 0.48, ROOM_ELITE: 0.26, ROOM_EVENT: 0.10, ROOM_TREASURE: 0.08, ROOM_MERCHANT: 0.08}
		"utility":
			weights = {ROOM_ENEMY: 0.38, ROOM_ELITE: 0.10, ROOM_EVENT: 0.22, ROOM_TREASURE: 0.14, ROOM_MERCHANT: 0.16}
		_:
			weights = {ROOM_ENEMY: 0.60, ROOM_ELITE: 0.16, ROOM_EVENT: 0.12, ROOM_TREASURE: 0.08, ROOM_MERCHANT: 0.04}

	if floor <= 2:
		weights[ROOM_ELITE] = 0.0
		weights[ROOM_MERCHANT] = 0.02

	return _pick_weighted_room(weights)


func _pick_weighted_room(weights: Dictionary) -> String:
	var total: float = 0.0
	for key in weights.keys():
		total += maxf(0.0, float(weights[key]))
	if total <= 0.0:
		return ROOM_ENEMY
	var roll: float = _rollf() * total
	for key in weights.keys():
		roll -= maxf(0.0, float(weights[key]))
		if roll <= 0.0:
			return str(key)
	return ROOM_ENEMY


func _ensure_map_generated() -> void:
	if map_generated_act == current_act and not map_nodes.is_empty():
		return

	map_nodes.clear()
	map_edges.clear()
	map_lane_profiles.clear()
	map_generated_act = current_act

	var lanes: int = max(3, map_lane_count)
	current_map_lane = clampi(current_map_lane, 0, lanes - 1)
	for lane in range(lanes):
		var profile: String = "combat"
		var r: int = _rolli_range(0, 2)
		if r == 1:
			profile = "elite"
		elif r == 2:
			profile = "utility"
		map_lane_profiles[lane] = profile

	map_nodes[current_floor] = [{
		"floor": current_floor,
		"lane": current_map_lane,
		"room_type": "CURRENT",
	}]

	var prev_lanes: PackedInt32Array = PackedInt32Array([current_map_lane])
	for floor in range(current_floor + 1, boss_floor + 1):
		var floor_nodes: Array[Dictionary] = []
		var lanes_this_floor: PackedInt32Array = PackedInt32Array()

		if floor == boss_floor:
			lanes_this_floor.append(lanes / 2)
		else:
			var path_progress: float = float(floor - current_floor) / float(max(1, boss_floor - current_floor))
			var desired_width: int = clampi(int(round(lerpf(float(lanes), 2.0, path_progress) + _rollf_range(-1.0, 1.0))), 2, lanes)
			var lane_set: Dictionary = {}
			for pl in prev_lanes:
				lane_set[clampi(int(pl) + _rolli_range(-1, 1), 0, lanes - 1)] = true
				if _rollf() < 0.35:
					lane_set[clampi(int(pl) + _rolli_range(-2, 2), 0, lanes - 1)] = true
			while lane_set.size() < desired_width:
				lane_set[_rolli_range(0, lanes - 1)] = true
			var lane_arr: Array = lane_set.keys()
			lane_arr.sort()
			while lane_arr.size() > desired_width:
				lane_arr.remove_at(_rolli_range(0, lane_arr.size() - 1))
			for l in lane_arr:
				lanes_this_floor.append(int(l))

		for lane in lanes_this_floor:
			floor_nodes.append({
				"floor": floor,
				"lane": lane,
				"room_type": _roll_room_type_for_floor(floor, lane),
			})
		map_nodes[floor] = floor_nodes

		for pl in prev_lanes:
			var choices: Array[int] = []
			for tl in lanes_this_floor:
				choices.append(int(tl))
			choices.sort_custom(func(a: int, b: int) -> bool:
				return abs(a - int(pl)) < abs(b - int(pl))
			)
			if choices.is_empty():
				continue
			var primary: int = choices[0]
			map_edges.append({"from_floor": floor - 1, "from_lane": int(pl), "to_floor": floor, "to_lane": primary})
			if choices.size() > 1 and _rollf() < 0.33:
				var idx: int = min(choices.size() - 1, _rolli_range(1, min(2, choices.size() - 1)))
				map_edges.append({"from_floor": floor - 1, "from_lane": int(pl), "to_floor": floor, "to_lane": choices[idx]})

		for tl in lanes_this_floor:
			var has_incoming: bool = false
			for edge in map_edges:
				if int(edge.get("to_floor", -1)) == floor and int(edge.get("to_lane", -1)) == int(tl):
					has_incoming = true
					break
			if has_incoming:
				continue
			var nearest_prev: int = int(prev_lanes[0])
			var best_dist: int = abs(nearest_prev - int(tl))
			for pl in prev_lanes:
				var dist: int = abs(int(pl) - int(tl))
				if dist < best_dist:
					best_dist = dist
					nearest_prev = int(pl)
			map_edges.append({"from_floor": floor - 1, "from_lane": nearest_prev, "to_floor": floor, "to_lane": int(tl)})

		prev_lanes = lanes_this_floor


func finish_run(victory: bool, reason: String) -> void:
	var floor_bonus: int = max(0, current_floor - 1) * 12
	var fight_bonus: int = int(run_stats.get("fights_won", 0.0)) * 16
	var effect_bonus: int = int(round(float(run_stats.get("effects_applied", 0.0)) * 1.5))
	var dot_bonus: int = int(round(float(run_stats.get("effect_damage", 0.0)) * 0.3))
	var heal_bonus: int = int(round(float(run_stats.get("healing_done", 0.0)) * 0.35))
	var tempo_bonus: int = max(0, 90 - int(run_stats.get("turns_spent", 0.0)))
	var victory_bonus: int = 140 if victory else 0
	var xp_gain: int = max(25, 40 + floor_bonus + fight_bonus + effect_bonus + dot_bonus + heal_bonus + tempo_bonus + victory_bonus)
	if victory and current_act >= total_acts and current_floor >= boss_floor:
		xp_gain = int(round(float(xp_gain) * final_victory_xp_multiplier))

	var xp_result: Dictionary = {}
	if has_node("/root/MetaProgression"):
		var meta_node: Node = get_node("/root/MetaProgression")
		if meta_node.has_method("add_xp"):
			xp_result = meta_node.call("add_xp", xp_gain)

	last_run_summary = {
		"victory": victory,
		"reason": reason,
		"floor_reached": current_floor,
		"act_reached": current_act,
		"gold": gold,
		"stats": run_stats.duplicate(true),
		"xp_gain": xp_gain,
		"xp_result": xp_result,
		"deck_size": deck.size(),
		"relic_count": relics.size(),
		"run_seed": run_seed,
	}
	log_combat("Run finished: %s (floor %d)" % [reason, current_floor])
	var save_node: Node = get_node_or_null("/root/SaveSystem")
	if save_node != null and save_node.has_method("append_run_history"):
		save_node.call("append_run_history", last_run_summary)
	get_tree().call_deferred("change_scene_to_file", run_result_scene_path)


func on_boss_defeated() -> bool:
	if current_act >= total_acts:
		finish_run(true, "Final boss defeated")
		return true
	current_act += 1
	current_floor = start_floor
	forced_room_type = ROOM_ENEMY
	current_enemy_data = null
	current_enemy_is_elite = false
	returning_from_fight = false
	reward_claimed = false
	map_nodes.clear()
	map_edges.clear()
	map_lane_profiles.clear()
	map_generated_act = -1
	current_map_lane = clampi(current_map_lane, 0, max(0, map_lane_count - 1))
	log_combat("Act advanced to %d" % current_act)
	record_replay_event("act_advance", {"act": current_act})
	get_tree().call_deferred("change_scene_to_file", level_scene_path)
	return false


func mark_card_seen(card_id: String) -> void:
	var meta_node: Node = get_node_or_null("/root/MetaProgression")
	if meta_node != null and meta_node.has_method("mark_card_seen"):
		meta_node.call("mark_card_seen", card_id)


func mark_relic_seen(relic_id: String) -> void:
	var meta_node: Node = get_node_or_null("/root/MetaProgression")
	if meta_node != null and meta_node.has_method("mark_relic_seen"):
		meta_node.call("mark_relic_seen", relic_id)


func mark_enemy_seen(enemy_id: String) -> void:
	var meta_node: Node = get_node_or_null("/root/MetaProgression")
	if meta_node != null and meta_node.has_method("mark_enemy_seen"):
		meta_node.call("mark_enemy_seen", enemy_id)


func mark_event_seen(event_id: String) -> void:
	var meta_node: Node = get_node_or_null("/root/MetaProgression")
	if meta_node != null and meta_node.has_method("mark_event_seen"):
		meta_node.call("mark_event_seen", event_id)


func sync_seen_from_run_state() -> void:
	for c in deck:
		if c != null:
			mark_card_seen(c.id)
	for r in relics:
		if r != null:
			mark_relic_seen(r.id)
	if current_enemy_data != null:
		mark_enemy_seen(current_enemy_data.resource_path)


func heal_from_campfire() -> int:
	var effective_percent: float = campfire_heal_percent + get_campfire_heal_bonus_percent()
	var amount: int = max(1, int(round(float(max_hp) * effective_percent)))
	current_hp = min(max_hp, current_hp + amount)
	return amount


func get_campfire_heal_bonus_percent() -> float:
	var bonus: float = 0.0
	for relic in relics:
		if relic == null:
			continue
		if not relic.is_active_for_time(is_night):
			continue
		bonus += relic.campfire_heal_bonus_percent
	return maxf(0.0, bonus)


func get_merchant_discount_percent() -> float:
	var bonus: float = 0.0
	for relic in relics:
		if relic == null:
			continue
		if not relic.is_active_for_time(is_night):
			continue
		bonus += relic.merchant_discount_percent
	return clampf(bonus, 0.0, 0.9)


func get_smith_discount_percent() -> float:
	var bonus: float = 0.0
	for relic in relics:
		if relic == null:
			continue
		if not relic.is_active_for_time(is_night):
			continue
		bonus += relic.smith_discount_percent
	return clampf(bonus, 0.0, 0.9)


func get_total_smith_free_upgrades() -> int:
	var free_upgrades: int = 0
	for relic in relics:
		if relic == null:
			continue
		if not relic.is_active_for_time(is_night):
			continue
		free_upgrades += max(0, relic.smith_free_upgrades)
	return free_upgrades


func get_remaining_smith_free_upgrades() -> int:
	return max(0, get_total_smith_free_upgrades() - used_smith_free_upgrades)


func consume_smith_upgrade(base_price: int) -> int:
	if get_remaining_smith_free_upgrades() > 0:
		used_smith_free_upgrades += 1
		return 0
	var discount: float = get_smith_discount_percent()
	return max(0, int(round(float(base_price) * (1.0 - discount))))


func get_smith_upgrade_price_preview(base_price: int) -> int:
	if get_remaining_smith_free_upgrades() > 0:
		return 0
	var discount: float = get_smith_discount_percent()
	return max(0, int(round(float(base_price) * (1.0 - discount))))


func apply_merchant_discount(base_price: int) -> int:
	var discount: float = get_merchant_discount_percent()
	return max(1, int(round(float(base_price) * (1.0 - discount))))


func get_floor_gold_multiplier(floor: int) -> float:
	if floor <= 3:
		return early_floor_gold_multiplier
	if floor <= 5:
		return mid_floor_gold_multiplier
	return 1.0


func get_merchant_purge_price(base_price: int, increment: int) -> int:
	var raw_price: int = max(0, base_price + (merchant_purge_count * max(0, increment)))
	return apply_merchant_discount(raw_price)


func consume_merchant_purge() -> void:
	merchant_purge_count += 1


func add_relic(relic: RelicData, heal_to_full_on_add: bool = false) -> void:
	if relic == null:
		return
	if relic.id.strip_edges() == "":
		return
	if relic.id != "" and has_relic_id(relic.id):
		return
	var relic_copy: RelicData = relic.duplicate(true) as RelicData
	if relic_copy == null:
		relic_copy = relic
	relics.append(relic_copy)
	mark_relic_seen(relic_copy.id)
	_recalculate_derived_stats()

	var heal_amount: int = max(0, relic_copy.heal_on_pickup_flat)
	if relic_copy.heal_on_pickup_percent > 0.0:
		heal_amount += int(round(float(max_hp) * relic_copy.heal_on_pickup_percent))
	if heal_to_full_on_add:
		current_hp = max_hp
	elif heal_amount > 0:
		current_hp = min(max_hp, current_hp + heal_amount)


func _recalculate_derived_stats() -> void:
	var hp_bonus: int = 0
	for relic in relics:
		if relic == null:
			continue
		if not relic.is_active_for_time(is_night):
			continue
		hp_bonus += relic.max_hp_bonus
	max_hp = max(1, base_max_hp + hp_bonus)
	current_hp = min(current_hp, max_hp)


func try_trigger_relic_revive() -> bool:
	for i in range(relics.size()):
		var relic: RelicData = relics[i]
		if relic == null:
			continue
		if not relic.one_time_revive:
			continue
		if not relic.is_active_for_time(is_night):
			continue
		if consumed_one_shot_relic_indices.has(i):
			continue
		consumed_one_shot_relic_indices[i] = true
		var pct: float = clampf(relic.revive_hp_percent, 0.01, 1.0)
		current_hp = max(1, int(round(float(max_hp) * pct)))
		return true
	return false


func apply_relic_card_modifiers(card: CardData) -> void:
	if card == null:
		return
	for relic in relics:
		if relic == null:
			continue
		if not relic.is_active_for_time(is_night):
			continue
		if not relic.has_card_stat_modifiers():
			continue
		if not _relic_matches_card(relic, card):
			continue

		if relic.attack_damage_bonus != 0:
			card.damage = max(0, card.damage + relic.attack_damage_bonus)
		if relic.defense_bonus != 0:
			card.defense = max(0, card.defense + relic.defense_bonus)
		if relic.cost_delta != 0:
			card.cost = max(0, card.cost + relic.cost_delta)
		if relic.effect_durability_bonus != 0:
			card.effect_durability = max(0, card.effect_durability + relic.effect_durability_bonus)
		if relic.buff_charges_bonus != 0:
			card.buff_charges = max(0, card.buff_charges + relic.buff_charges_bonus)


func _relic_matches_card(relic: RelicData, card: CardData) -> bool:
	if not relic.card_id_filters.is_empty() and not relic.card_id_filters.has(card.id):
		return false
	if relic.use_card_type_filter and card.get_card_type() != relic.card_type_filter:
		return false
	if relic.require_upgraded_card and not card.is_upgraded():
		return false
	return true


func has_relic_id(relic_id: String) -> bool:
	if relic_id == "":
		return false
	for relic in relics:
		if relic == null:
			continue
		if relic.id == relic_id:
			return true
	return false


func apply_starting_relics() -> void:
	for relic in starting_relics:
		add_relic(relic, false)
	_recalculate_derived_stats()


func bootstrap_starting_relics_from_fight_scene() -> void:
	if not starting_relics.is_empty():
		return

	var fight_scene: PackedScene = load("res://fight.tscn") as PackedScene
	if fight_scene == null:
		return
	var fight_root: Node = fight_scene.instantiate()
	if fight_root == null:
		return

	var battle_manager_node: Node = fight_root.get_node_or_null("BattleManager")
	if battle_manager_node == null:
		fight_root.queue_free()
		return

	var bm_relics_variant: Variant = battle_manager_node.get("starting_relics")
	if bm_relics_variant is Array:
		var bm_relics: Array = bm_relics_variant
		for relic_variant in bm_relics:
			if relic_variant is RelicData:
				starting_relics.append(relic_variant as RelicData)

	fight_root.queue_free()


func get_available_card_pool() -> Array[CardData]:
	if all_cards_cache.is_empty():
		_load_content_pools()
	var out: Array[CardData] = []
	for card in all_cards_cache:
		if card == null:
			continue
		if has_node("/root/MetaProgression"):
			var meta_node: Node = get_node("/root/MetaProgression")
			if meta_node.has_method("is_card_unlocked") and not bool(meta_node.call("is_card_unlocked", card)):
				continue
		out.append(card)
	return out


func get_available_relic_pool() -> Array[RelicData]:
	if all_relics_cache.is_empty():
		_load_content_pools()
	var out: Array[RelicData] = []
	for relic in all_relics_cache:
		if relic == null:
			continue
		if relic.id.strip_edges() == "":
			continue
		if relic.is_starter_relic:
			continue
		if has_node("/root/MetaProgression"):
			var meta_node: Node = get_node("/root/MetaProgression")
			if meta_node.has_method("is_relic_unlocked") and not bool(meta_node.call("is_relic_unlocked", relic)):
				continue
		out.append(relic)
	return out


func export_state() -> Dictionary:
	var data: Dictionary = {}
	data["version"] = 1
	data["current_floor"] = current_floor
	data["current_act"] = current_act
	data["gold"] = gold
	data["pending_gold"] = pending_gold
	data["battle_speed_mult"] = battle_speed_mult
	data["current_hp"] = current_hp
	data["current_enemy_is_elite"] = current_enemy_is_elite
	data["returning_from_fight"] = returning_from_fight
	data["reward_claimed"] = reward_claimed
	data["used_smith_free_upgrades"] = used_smith_free_upgrades
	data["merchant_purge_count"] = merchant_purge_count
	data["is_night"] = is_night
	data["forced_room_type"] = forced_room_type
	data["map_nodes"] = map_nodes
	data["map_edges"] = map_edges
	data["map_lane_profiles"] = map_lane_profiles
	data["map_generated_act"] = map_generated_act
	data["current_map_lane"] = current_map_lane
	data["combat_log"] = combat_log
	data["combat_events"] = combat_events
	data["replay_events"] = replay_events
	data["run_seed"] = run_seed
	data["rng_state"] = rng_state
	data["run_stats"] = run_stats
	data["last_run_summary"] = last_run_summary
	data["current_enemy_path"] = current_enemy_data.resource_path if current_enemy_data != null else ""
	data["deck"] = _serialize_card_array(deck)
	data["relics"] = _serialize_relic_array(relics)
	var consumed: Array[int] = []
	for idx_any in consumed_one_shot_relic_indices.keys():
		consumed.append(int(idx_any))
	data["consumed_one_shot_relic_indices"] = consumed
	return data


func import_state(data: Dictionary) -> void:
	if data.is_empty():
		return

	current_floor = int(data.get("current_floor", start_floor))
	current_act = int(data.get("current_act", start_act))
	gold = int(data.get("gold", start_gold))
	pending_gold = int(data.get("pending_gold", 0))
	battle_speed_mult = clampi(int(data.get("battle_speed_mult", battle_speed_min)), battle_speed_min, battle_speed_max)
	current_enemy_is_elite = bool(data.get("current_enemy_is_elite", false))
	returning_from_fight = bool(data.get("returning_from_fight", false))
	reward_claimed = bool(data.get("reward_claimed", false))
	used_smith_free_upgrades = int(data.get("used_smith_free_upgrades", 0))
	merchant_purge_count = int(data.get("merchant_purge_count", 0))
	is_night = bool(data.get("is_night", false))
	forced_room_type = str(data.get("forced_room_type", ""))
	current_map_lane = int(data.get("current_map_lane", 1))

	var map_any: Variant = data.get("map_nodes", {})
	if typeof(map_any) == TYPE_DICTIONARY:
		map_nodes.clear()
		var map_dict: Dictionary = map_any as Dictionary
		for k in map_dict.keys():
			map_nodes[int(k)] = map_dict[k]
	else:
		map_nodes = {}
	var map_edges_any: Variant = data.get("map_edges", [])
	if map_edges_any is Array:
		map_edges = (map_edges_any as Array).duplicate(true)
	else:
		map_edges = []
	var map_profiles_any: Variant = data.get("map_lane_profiles", {})
	if typeof(map_profiles_any) == TYPE_DICTIONARY:
		map_lane_profiles = (map_profiles_any as Dictionary).duplicate(true)
	else:
		map_lane_profiles = {}
	map_generated_act = int(data.get("map_generated_act", -1))

	var log_any: Variant = data.get("combat_log", [])
	combat_log.clear()
	if log_any is Array:
		for item in log_any:
			combat_log.append(str(item))
	var combat_events_any: Variant = data.get("combat_events", [])
	combat_events.clear()
	if combat_events_any is Array:
		for ev_any in combat_events_any:
			if typeof(ev_any) == TYPE_DICTIONARY:
				combat_events.append((ev_any as Dictionary).duplicate(true))
	var replay_events_any: Variant = data.get("replay_events", [])
	replay_events.clear()
	if replay_events_any is Array:
		for replay_any in replay_events_any:
			if typeof(replay_any) == TYPE_DICTIONARY:
				replay_events.append((replay_any as Dictionary).duplicate(true))
	run_seed = int(data.get("run_seed", run_seed))
	rng_state = int(data.get("rng_state", run_seed))
	if run_seed != 0:
		_init_rng(run_seed)
		if rng_state != 0:
			seed(rng_state)

	var stats_any: Variant = data.get("run_stats", {})
	if typeof(stats_any) == TYPE_DICTIONARY:
		run_stats = (stats_any as Dictionary).duplicate(true)

	var summary_any: Variant = data.get("last_run_summary", {})
	if typeof(summary_any) == TYPE_DICTIONARY:
		last_run_summary = (summary_any as Dictionary).duplicate(true)
	else:
		last_run_summary = {}

	_ensure_enemy_pools_for_current_act()
	deck = _deserialize_card_array(data.get("deck", []))
	relics = _deserialize_relic_array(data.get("relics", []))
	for c in deck:
		if c != null:
			mark_card_seen(c.id)
	for r in relics:
		if r != null:
			mark_relic_seen(r.id)
	consumed_one_shot_relic_indices.clear()
	var consumed: Array = data.get("consumed_one_shot_relic_indices", [])
	for idx_any in consumed:
		consumed_one_shot_relic_indices[int(idx_any)] = true

	current_enemy_data = null
	var enemy_path: String = str(data.get("current_enemy_path", ""))
	if enemy_path != "":
		var enemy_res: Resource = load(enemy_path)
		if enemy_res is EnemyData:
			current_enemy_data = enemy_res as EnemyData

	_recalculate_derived_stats()
	current_hp = clampi(int(data.get("current_hp", max_hp)), 1, max_hp)
	_ensure_run_stat_defaults()


func _ensure_run_stat_defaults() -> void:
	var defaults: Dictionary = {
		"fights_won": 0.0,
		"fights_lost": 0.0,
		"turns_spent": 0.0,
		"effects_applied": 0.0,
		"effect_damage": 0.0,
		"healing_done": 0.0,
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
	}
	for key in defaults.keys():
		if not run_stats.has(key):
			run_stats[key] = defaults[key]


func _serialize_card_array(cards: Array[CardData]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for card in cards:
		if card == null:
			continue
		out.append({
			"path": card.resource_path,
			"id": card.id,
			"upgraded": card.is_upgraded(),
		})
	return out


func _deserialize_card_array(raw: Array) -> Array[CardData]:
	var out: Array[CardData] = []
	for item_any in raw:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any
		var card_template: CardData = null
		var path: String = str(item.get("path", ""))
		if path != "":
			var loaded: Resource = load(path)
			if loaded is CardData:
				card_template = loaded as CardData
		if card_template == null:
			var target_id: String = str(item.get("id", ""))
			for c in get_available_card_pool():
				if c != null and c.id == target_id:
					card_template = c
					break
		if card_template == null:
			continue
		var card_copy: CardData = card_template.duplicate(true) as CardData
		if card_copy == null:
			card_copy = card_template
		card_copy.set_upgraded(bool(item.get("upgraded", false)))
		out.append(card_copy)
	return out


func _serialize_relic_array(items: Array[RelicData]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for relic in items:
		if relic == null:
			continue
		out.append({
			"path": relic.resource_path,
			"id": relic.id,
		})
	return out


func _deserialize_relic_array(raw: Array) -> Array[RelicData]:
	var out: Array[RelicData] = []
	for item_any in raw:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any
		var relic_template: RelicData = null
		var path: String = str(item.get("path", ""))
		if path != "":
			var loaded: Resource = load(path)
			if loaded is RelicData:
				relic_template = loaded as RelicData
		if relic_template == null:
			var target_id: String = str(item.get("id", ""))
			for r in get_available_relic_pool():
				if r != null and r.id == target_id:
					relic_template = r
					break
		if relic_template == null:
			continue
		var relic_copy: RelicData = relic_template.duplicate(true) as RelicData
		if relic_copy == null:
			relic_copy = relic_template
		out.append(relic_copy)
	return out
