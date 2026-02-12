extends Control

@onready var slider: HSlider = $Panel/VBox/VolumeSlider
@onready var value_label: Label = $Panel/VBox/ValueLabel
@onready var back_btn: Button = $Panel/VBox/BackBtn

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	slider.value_changed.connect(_on_volume_changed)

	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx == -1:
		bus_idx = AudioServer.get_bus_index("Master")
	var db := AudioServer.get_bus_volume_db(bus_idx)
	var linear := db_to_linear(db)
	slider.value = linear
	_update_label(linear)

func _on_volume_changed(v: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx == -1:
		bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(0.0001, v)))
	_update_label(v)

func _update_label(v: float) -> void:
	value_label.text = "Громкость: %d%%" % int(round(v * 100.0))

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
