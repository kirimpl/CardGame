extends Area2D

var player_in_range: bool = false
var typing_generation: int = 0

@export var prompt_text: String = "Нажмите на U"
@export var type_char_delay: float = 0.03

@onready var prompt_label: Label = get_node_or_null("Label")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_hide_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		open_chest()

func open_chest() -> void:
	var reward_ui = preload("res://UI/reward_ui.tscn").instantiate()
	get_tree().current_scene.add_child(reward_ui)

	_hide_prompt()
	hide()
	monitoring = false

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = true
		_show_prompt_typed()

func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = false
		_hide_prompt()

func _is_player(body: Node) -> bool:
	return body != null and (body.name == "Player" or body.is_in_group("Player"))

func _hide_prompt() -> void:
	typing_generation += 1
	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = ""

func _show_prompt_typed() -> void:
	if prompt_label == null:
		return
	typing_generation += 1
	var local_generation: int = typing_generation
	prompt_label.visible = true
	prompt_label.text = ""
	for i in range(prompt_text.length()):
		if local_generation != typing_generation or not player_in_range:
			return
		prompt_label.text = prompt_text.substr(0, i + 1)
		await get_tree().create_timer(type_char_delay).timeout
