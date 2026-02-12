extends Node2D

# Shared combat helpers. Kept syntax-compatible for Godot 4.x.
var max_hp := 1
var hp := 1
var damage := 1
var current_defense := 0
var hit_frame := 2
@onready var anim = get_node_or_null("AnimatedSprite2D")

func take_damage(amount):
	var incoming = max(0, int(amount))
	if current_defense > 0:
		var absorbed = min(int(current_defense), incoming)
		current_defense -= absorbed
		incoming -= absorbed

	hp = max(0, int(hp) - incoming)
	return incoming

func _play_anim(name):
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation(name):
		if anim.animation != name:
			anim.play(name)

func _wait_hit_frame(attack_animation := "Attack"):
	while anim and anim.frame < int(hit_frame) and anim.is_playing() and anim.animation == attack_animation:
		await get_tree().process_frame
