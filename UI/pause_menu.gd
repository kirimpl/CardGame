extends Control
class_name PauseMenu

signal resume_requested
signal save_exit_requested
signal settings_requested
signal extra_requested

@onready var title_label: Label = $Dim/Panel/Margin/VBox/Title
@onready var extra_btn: Button = $Dim/Panel/Margin/VBox/ExtraButton


func _ready() -> void:
	visible = false
	$Dim.mouse_filter = Control.MOUSE_FILTER_STOP
	$Dim/Panel/Margin/VBox/ContinueButton.pressed.connect(_on_continue_pressed)
	$Dim/Panel/Margin/VBox/ExtraButton.pressed.connect(_on_extra_pressed)
	$Dim/Panel/Margin/VBox/SettingsButton.pressed.connect(_on_settings_pressed)
	$Dim/Panel/Margin/VBox/SaveExitButton.pressed.connect(_on_save_exit_pressed)


func open_menu(title_text: String = "Menu", extra_text: String = "", show_extra: bool = false) -> void:
	title_label.text = title_text
	extra_btn.visible = show_extra
	if show_extra:
		extra_btn.text = extra_text
	visible = true


func close_menu() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _on_continue_pressed() -> void:
	emit_signal("resume_requested")


func _on_extra_pressed() -> void:
	emit_signal("extra_requested")


func _on_settings_pressed() -> void:
	emit_signal("settings_requested")


func _on_save_exit_pressed() -> void:
	emit_signal("save_exit_requested")
