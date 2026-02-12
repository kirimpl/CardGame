extends Node2D

func _ready() -> void:
	await Transition.fade_in(0.2)

	if GameState.starter == GameState.Starter.PLAYER:
		print("Первый ход: игрок")
	else:
		print("Первый ход: враг")
