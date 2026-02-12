extends Area2D

var player_in_range: bool = false

func _ready() -> void:
	# Подключаем сигналы входа/выхода из зоны через код (или сделай через редактор)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	# Проверяем нажатие кнопки действия (настрой "interact" в Input Map на клавишу E)
	# Или используй "ui_accept" (обычно Пробел/Enter)
	if player_in_range and event.is_action_pressed("interact"):
		open_chest()

func open_chest() -> void:
	print("Сундук открыт!")
	# Загружаем сцену окна наград
	var reward_ui = preload("res://UI/reward_ui.tscn").instantiate()
	# Добавляем её в корень сцены, чтобы она была над всем
	get_tree().current_scene.add_child(reward_ui)
	
	hide()
	monitoring = false
	# Скрываем сундук (портал покажется после завершения награды)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = true
		# Тут можно показать надпись "Press E"

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false
