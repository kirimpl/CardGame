extends Node2D



func _on_quit_pressed() -> void:
	var meta: Node = get_node_or_null("/root/MetaProgression")
	if meta != null and meta.has_method("save_profile"):
		meta.call("save_profile")
	get_tree().quit();


func _on_play_pressed() -> void:
	RunManager.start_new_run()
	await Transition.fade_out(1.0)
	get_tree().change_scene_to_file("res://level.tscn");
	await Transition.fade_in(1.0)

func _on_settings_pressed() -> void:
	await Transition.fade_out(0.5)
	get_tree().change_scene_to_file("res://settings.tscn")
	await Transition.fade_in(0.5)


func _on_codex_pressed() -> void:
	RunManager.sync_seen_from_run_state()
	var meta: Node = get_node_or_null("/root/MetaProgression")
	if meta != null and meta.has_method("save_profile"):
		meta.call("save_profile")
	await Transition.fade_out(0.5)
	get_tree().change_scene_to_file("res://UI/compendium.tscn")
	await Transition.fade_in(0.5)
