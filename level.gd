extends Node2D

var fight_started := false
var enemy: Node = null

@export var enemy_overworld_scene: PackedScene = preload("res://Mob/EnemyOverworld.tscn")

@onready var mobs_root: Node2D = $Mobs
@onready var enemy_spawn: Node2D = $Mobs/EnemySpawn
@onready var chest: Area2D = $Chest
@onready var portal: Area2D = $Portal
@onready var player: Node2D = $Player/Player
@onready var hp_label: Label = get_node_or_null("HUD/HPLabel")
@onready var gold_label: Label = get_node_or_null("HUD/GoldLabel")
@onready var floor_label: Label = get_node_or_null("HUD/FloorLabel")

func _ready() -> void:
	# Синхронизируем HP
	if player and ("hp" in player):
		RunManager.current_hp = int(player.hp)
	_update_hud()
	# Игрок -> удар по врагу
	if player.has_signal("hit_enemy") and not player.hit_enemy.is_connected(_on_player_hit_enemy):
		player.hit_enemy.connect(_on_player_hit_enemy)

	if RunManager.returning_from_fight:
		_setup_victory_state()
	else:
		_setup_battle_state()

func _setup_battle_state() -> void:
	_spawn_random_enemy()

	chest.hide(); chest.monitoring = false
	portal.hide(); portal.monitoring = false

func _setup_victory_state() -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()

	if RunManager.reward_claimed:
		chest.hide(); chest.monitoring = false
		portal.show(); portal.monitoring = true
	else:
		chest.show(); chest.monitoring = true
		portal.hide(); portal.monitoring = false

func _spawn_random_enemy() -> void:
	if enemy_overworld_scene == null:
		push_error("Level: enemy_overworld_scene не назначена!")
		return

	# На всякий случай очищаем старого
	if is_instance_valid(enemy):
		enemy.queue_free()
		enemy = null

	var picked: EnemyData = RunManager.pick_enemy_for_floor()
	if picked == null:
		push_error("Level: не удалось выбрать EnemyData (пулы пустые).")
		return

	enemy = enemy_overworld_scene.instantiate()
	enemy.global_position = enemy_spawn.global_position

	# Передаём EnemyData в оверворлд-врага
	if "data" in enemy:
		enemy.data = picked

	# Добавляем в сцену ПОСЛЕ того, как присвоили data (иначе _ready() может отработать с null)
	mobs_root.add_child(enemy)

	# Враг -> старт боя
	if enemy.has_signal("start_battle") and not enemy.start_battle.is_connected(_on_enemy_start_battle):
		enemy.start_battle.connect(_on_enemy_start_battle)

func _on_enemy_start_battle(enemy_data: EnemyData) -> void:
	start_fight_logic(enemy_data, GameState.Starter.ENEMY)

func _on_player_hit_enemy(target_node: Node) -> void:
	if not is_instance_valid(enemy):
		return

	# Если игрок ударил врага (или его хитбокс)
	if target_node == enemy or target_node.get_parent() == enemy:
		var data_to_use: EnemyData = null
		if "data" in enemy:
			data_to_use = enemy.data

		if data_to_use:
			start_fight_logic(data_to_use, GameState.Starter.PLAYER)

func start_fight_logic(enemy_data: EnemyData, starter: GameState.Starter) -> void:
	if fight_started:
		return
	fight_started = true

	RunManager.current_enemy_data = enemy_data

	GameState.starter = starter
	GameState.return_scene = "res://level.tscn"
	GameState.spawn_pos = player.global_position

	call_deferred("_change_scene_safe")

func _change_scene_safe() -> void:
	get_tree().change_scene_to_file("res://fight.tscn")

func _on_portal_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		RunManager.next_floor()



func _on_chest_opened() -> void:
	# Сундук открыт и награда получена/пропущена -> показываем портал
	chest.hide()
	chest.monitoring = false
	portal.show()
	portal.monitoring = true

func _process(_delta: float) -> void:
	_update_hud()

func _update_hud() -> void:
	if hp_label:
		hp_label.text = "HP: %d/%d" % [int(RunManager.current_hp), int(RunManager.max_hp)]
	if gold_label:
		gold_label.text = "Gold: %d" % int(RunManager.gold)
	if floor_label:
		floor_label.text = "Floor: %d" % int(RunManager.current_floor)
