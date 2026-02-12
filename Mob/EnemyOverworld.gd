extends CharacterBody2D

signal start_battle(enemy_data: EnemyData)

@export var data: EnemyData 

const SPEED := 150.0
const DETECT_DELAY := 3.0  

const GRAVITY_MULTIPLIER := 1.0 

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitboxes: Node2D = $Hitboxes
@onready var attack_area: Area2D = $Hitboxes/AttackArea
@onready var detector: Area2D = $Detector 

var chase := false
var facing_right := true
var player_ref: Node2D = null
var player_in_detector := false
var detector_waiting := false
var is_detecting := false

func _ready() -> void:
	add_to_group("Enemy")
	
	if data:
		scale = Vector2(data.scale, data.scale) 
		if anim:
			if data.sprite_frames:
				anim.sprite_frames = data.sprite_frames
			anim.position = data.overworld_offset
			anim.flip_h = data.flip_h 
		anim.play("Idle")
	else:
		push_warning("⚠️ EnemyOverworld: Data не назначена!")

	attack_area.monitoring = true
	attack_area.monitorable = true

	if anim.sprite_frames and anim.sprite_frames.has_animation("Detect"):
		anim.sprite_frames.set_animation_loop("Detect", false)

func _physics_process(delta: float) -> void:

	if not is_on_floor():

		velocity += get_gravity() * delta * GRAVITY_MULTIPLIER
	

	if is_detecting:

		velocity.x = 0
	elif chase and player_ref:

		var dir := player_ref.global_position - global_position
		velocity.x = sign(dir.x) * SPEED

		if dir.x != 0.0:
			facing_right = dir.x > 0.0
	
			if data and data.flip_h:
				anim.flip_h = not facing_right 
			else:
				anim.flip_h = facing_right 
			hitboxes.scale.x = -1 if facing_right else 1
		play_anim("Run")
	else:
		# Безделье
		velocity.x = 0
		play_anim("Idle")


	move_and_slide()



func _on_detector_body_entered(body: Node) -> void:
	if not _is_player(body): return
	player_ref = body
	player_in_detector = true
	is_detecting = true
	chase = false
	if anim.sprite_frames and anim.sprite_frames.has_animation("Detect"):
		anim.play("Detect")
	if detector_waiting: return
	detector_waiting = true
	await get_tree().create_timer(DETECT_DELAY).timeout
	detector_waiting = false
	if player_in_detector:
		is_detecting = false
		chase = true

func _on_detector_body_exited(body: Node) -> void:
	if not _is_player(body): return
	player_in_detector = false
	detector_waiting = false
	is_detecting = false
	chase = false
	player_ref = null
	play_anim("Idle")

func _on_attack_trigger_body_entered(body: Node) -> void:
	if not chase: return
	if _is_player(body): _trigger_battle()

func _on_attack_area_body_entered(body: Node) -> void:
	if _is_player(body): _trigger_battle()

func _trigger_battle() -> void:
	if data == null: return
	emit_signal("start_battle", data)
	queue_free() 

func play_anim(name: StringName) -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation(name):
		if anim.animation != name:
			anim.play(name)

func _is_player(body: Node) -> bool:
	return body != null and (body.name == "Player" or body.is_in_group("Player"))

func _on_animated_sprite_2d_animation_finished() -> void:
	pass
