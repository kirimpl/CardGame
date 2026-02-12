extends CanvasLayer

@onready var fade: ColorRect = $Fade
var busy := false

func fade_out(time := 0.2) -> void:
	if busy: return
	busy = true
	fade.visible = true
	fade.modulate.a = 0.0

	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, time)
	await t.finished

func fade_in(time := 0.2) -> void:
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 0.0, time)
	await t.finished

	fade.visible = false
	busy = false
