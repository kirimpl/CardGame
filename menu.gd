extends Node2D



func _on_quit_pressed() -> void:
	get_tree().quit();


func _on_play_pressed() -> void:
	await Transition.fade_out(1.0)
	get_tree().change_scene_to_file("res://level.tscn");
	await Transition.fade_in(1.0)

func _on_settings_pressed() -> void:
	await Transition.fade_out(0.5)
	get_tree().change_scene_to_file("res://settings.tscn")
	await Transition.fade_in(0.5)
