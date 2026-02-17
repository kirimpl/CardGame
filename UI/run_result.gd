extends CanvasLayer

@onready var title_label: Label = $Root/Panel/Margin/VBox/Title
@onready var reason_label: Label = $Root/Panel/Margin/VBox/Reason
@onready var stats_label: Label = $Root/Panel/Margin/VBox/Stats
@onready var xp_label: Label = $Root/Panel/Margin/VBox/XP


func _ready() -> void:
	var summary: Dictionary = RunManager.last_run_summary
	var victory: bool = bool(summary.get("victory", false))
	title_label.text = "Run Complete" if victory else "Run Failed"
	reason_label.text = str(summary.get("reason", ""))

	var stats: Dictionary = summary.get("stats", {})
	var floor_reached: int = int(summary.get("floor_reached", RunManager.current_floor))
	var turns: int = int(stats.get("turns_spent", 0))
	var wins: int = int(stats.get("fights_won", 0))
	var effects: int = int(stats.get("effects_applied", 0))
	var dot_dmg: int = int(stats.get("effect_damage", 0))
	var healed: int = int(stats.get("healing_done", 0))
	stats_label.text = "Floor reached: %d\nFights won: %d\nTurns: %d\nEffects applied: %d\nEffect damage: %d\nHealing: %d" % [
		floor_reached,
		wins,
		turns,
		effects,
		dot_dmg,
		healed,
	]

	var xp_gain: int = int(summary.get("xp_gain", 0))
	var xp_result: Dictionary = summary.get("xp_result", {})
	var level_now: int = int(xp_result.get("new_level", 1))
	var levels_gained: int = int(xp_result.get("levels_gained", 0))
	var xp_in_level: int = int(xp_result.get("xp_in_level", 0))
	var xp_to_next: int = int(xp_result.get("xp_to_next", 0))
	xp_label.text = "XP +%d\nLevel: %d (+%d)\nProgress: %d / %d" % [xp_gain, level_now, levels_gained, xp_in_level, xp_to_next]


func _on_new_run_pressed() -> void:
	RunManager.start_new_run()
	get_tree().change_scene_to_file("res://level.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
