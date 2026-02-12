extends Node

@export_group("Run Defaults")
@export var start_floor: int = 1
@export var start_act: int = 1
@export var start_gold: int = 0
@export var max_hp: int = 96
@export_range(1, 20, 1) var battle_speed_min: int = 1
@export_range(1, 20, 1) var battle_speed_max: int = 5
@export_range(1, 100, 1) var floors_per_act: int = 9
@export_range(1, 100, 1) var boss_floor: int = 10
@export_range(0.0, 1.0, 0.01) var elite_chance: float = 0.24
@export_range(1.0, 5.0, 0.05) var elite_gold_multiplier: float = 1.65

var current_floor: int = 1
var current_act: int = 1
var gold: int = 0
var pending_gold: int = 0
var battle_speed_mult: int = 1
var current_hp: int = 100
var current_enemy_data: EnemyData = null
var current_enemy_is_elite: bool = false
var returning_from_fight: bool = false
var reward_claimed: bool = false
var deck: Array[CardData] = []

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
	current_hp = max_hp
	current_enemy_data = null
	battle_speed_mult = clampi(battle_speed_mult, battle_speed_min, battle_speed_max)
	current_enemy_is_elite = false
	returning_from_fight = false
	reward_claimed = false
	deck.clear()

	
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
