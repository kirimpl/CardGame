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
@export var starting_relics: Array[RelicData] = []

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

# --- Пулы врагов ---
var normal_enemies: Array[EnemyData] = []
var elite_enemies: Array[EnemyData] = []
var boss_enemies: Array[EnemyData] = []

func _ready() -> void:
	start_new_run()
	_randomize_once()
	_load_enemy_pools()

func _randomize_once() -> void:

	if Engine.get_frames_drawn() == 0:
		randomize()



	
func _load_enemy_pools() -> void:
	normal_enemies.clear()
	elite_enemies.clear()
	boss_enemies.clear()

	var stack: Array[String] = ["res://Enemies"]

	while not stack.is_empty():
		var dir_path: String = stack.pop_back()

		var dir := DirAccess.open(dir_path)
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
			elif file_name.get_extension() == "tres":
				var res: Resource = load(full)
				if res is EnemyData:
					_match_and_add_enemy(res as EnemyData)

			file_name = dir.get_next()

		dir.list_dir_end()

	if normal_enemies.is_empty() and elite_enemies.is_empty() and boss_enemies.is_empty():
		push_warning("RunManager: Не найдено ни одного EnemyData в res://Enemies")


func _match_and_add_enemy(e: EnemyData) -> void:
	match e.difficulty:
		EnemyData.Difficulty.ELITE:
			elite_enemies.append(e)
		EnemyData.Difficulty.BOSS:
			boss_enemies.append(e)
		_:
			normal_enemies.append(e)

func pick_enemy_for_floor() -> EnemyData:
	var diff: String = get_enemy_difficulty()
	var pool: Array[EnemyData] = []
	match diff:
		"ELITE": pool = elite_enemies
		"BOSS": pool = boss_enemies
		_: pool = normal_enemies


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

func start_new_run():
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
	deck.clear()
	relics.clear()
	consumed_one_shot_relic_indices.clear()
	bootstrap_starting_relics_from_fight_scene()
	apply_starting_relics()

	
func next_floor():
	current_floor += 1
	current_enemy_is_elite = false
	returning_from_fight = false
	reward_claimed = false
	
	if current_floor > floors_per_act:
		current_floor = start_floor
		current_act += 1
	
	
	get_tree().call_deferred("change_scene_to_file", "res://level.tscn")

func get_enemy_difficulty() -> String:

	if current_floor == boss_floor:
		return "BOSS"
	
	
	if randf() < elite_chance:
		return "ELITE"
		
	return "NORMAL"


func add_relic(relic: RelicData, heal_to_full_on_add: bool = false) -> void:
	if relic == null:
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


func bootstrap_starting_relics_from_fight_scene() -> void:
	# Allow configuring starting relics in BattleManager inspector (fight.tscn),
	# while still applying them from the beginning of Level.
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
