extends Node

@export_group("Run Defaults")
@export var start_floor: int = 1
@export var start_act: int = 1
@export var start_gold: int = 0
@export var base_max_hp: int = 96
@export_range(1, 20, 1) var battle_speed_min: int = 1
@export_range(1, 20, 1) var battle_speed_max: int = 5
@export_range(1, 100, 1) var floors_per_act: int = 9
@export_range(1, 100, 1) var boss_floor: int = 10
@export_range(0.0, 1.0, 0.01) var elite_chance: float = 0.24
@export_range(1.0, 5.0, 0.05) var elite_gold_multiplier: float = 1.65
@export_range(0.0, 1.0, 0.01) var multi_enemy_chance: float = 0.4
@export_range(2, 4, 1) var multi_enemy_max_count: int = 2
@export var starting_relics: Array[RelicData] = []
@export var guaranteed_rest_floors: PackedInt32Array = PackedInt32Array([5, 9])
@export_file("*.tscn") var level_scene_path: String = "res://level.tscn"
@export_file("*.tscn") var rest_room_scene_path: String = "res://level.tscn"
@export_range(0.0, 1.0, 0.01) var campfire_heal_percent: float = 0.4
@export_range(1.0, 3.0, 0.05) var night_enemy_hp_multiplier: float = 1.25
@export_range(1.0, 3.0, 0.05) var night_enemy_damage_multiplier: float = 1.2

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
var is_night: bool = false

var normal_enemies: Array[EnemyData] = []
var elite_enemies: Array[EnemyData] = []
var boss_enemies: Array[EnemyData] = []
var all_cards_cache: Array[CardData] = []
var all_relics_cache: Array[RelicData] = []
var loaded_enemy_act: int = -1

func _ready() -> void:
	start_new_run()
	_randomize_once()
	_load_enemy_pools()
	_load_content_pools()


func _randomize_once() -> void:
	if Engine.get_frames_drawn() == 0:
		randomize()


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

	current_enemy_data = pool.pick_random() as EnemyData
	current_enemy_is_elite = (diff == "ELITE")
	return current_enemy_data


func get_fight_enemy_count() -> int:
	if current_enemy_data == null:
		return 1
	if current_enemy_data.difficulty == EnemyData.Difficulty.BOSS:
		return 1
	if multi_enemy_max_count < 2:
		return 1
	if randf() >= multi_enemy_chance:
		return 1
	return randi_range(2, multi_enemy_max_count)


func start_new_run() -> void:
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
	bootstrap_starting_relics_from_fight_scene()
	apply_starting_relics()


func next_floor() -> void:
	current_floor += 1
	current_enemy_is_elite = false
	returning_from_fight = false
	reward_claimed = false

	if current_floor > floors_per_act:
		current_floor = start_floor
		current_act += 1

	get_tree().call_deferred("change_scene_to_file", get_scene_for_floor(current_floor))


func is_rest_floor(floor: int) -> bool:
	return guaranteed_rest_floors.has(floor)


func get_scene_for_floor(floor: int) -> String:
	if is_rest_floor(floor):
		return rest_room_scene_path
	return level_scene_path


func get_enemy_difficulty() -> String:
	if current_floor == boss_floor:
		return "BOSS"
	if randf() < elite_chance:
		return "ELITE"
	return "NORMAL"


func toggle_day_night() -> void:
	is_night = not is_night
	_recalculate_derived_stats()


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
	return all_cards_cache


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
		out.append(relic)
	return out
