extends CharacterBody2D

signal hit_enemy(enemy: Node) 

var hp: int = 0
var max_hp: int = 0

const SPEED := 250.0
const JUMP_VELOCITY := -400.0
const HIT_FRAME := 3                     
const DAMAGE_WINDOW_TIME := 0.10      
const HITSTOP_SCALE := 0.20           
const HITSTOP_REAL_TIME := 0.12       
const AFTER_HIT_DELAY_REAL := 0.4   

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitboxes: Node2D = $Hitboxes
@onready var attack_area: Area2D = $Hitboxes/AttackArea

var is_attacking := false
var direction := 0.0
var facing_right := true
var damage_window := false
var hit_sent := false

func _ready() -> void:
	max_hp = RunManager.max_hp
	hp = RunManager.current_hp
	attack_area.monitoring = true
	attack_area.monitorable = true

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY
	direction = Input.get_axis("ui_left", "ui_right")
	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack()
	if not is_attacking:
		if direction != 0:
			velocity.x = direction * SPEED
			facing_right = direction > 0
			anim.flip_h = direction < 0
			hitboxes.scale.x = 1 if facing_right else -1
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = 0.0
	if not is_attacking:
		play_normal_anim()
	move_and_slide()
	if velocity.y > 0 and not is_attacking:
		anim.play("Fall")

func start_attack() -> void:
	is_attacking = true
	hit_sent = false
	damage_window = false
	anim.play("Attack")
	await _wait_attack_hit_frame()
	damage_window = true
	var enemy := _check_enemy_overlap()
	damage_window = false
	if enemy != null:
		await _do_hit_sequence_on_enemy(enemy)
		hit_sent = true
		emit_signal("hit_enemy", enemy)

func _wait_attack_hit_frame() -> void:
	while anim.animation == "Attack" and anim.frame < HIT_FRAME:
		await anim.frame_changed

func _check_enemy_overlap() -> Node:
	for b in attack_area.get_overlapping_bodies():
		if b and b.is_in_group("Enemy"):
			return b
	return null

func _do_hit_sequence_on_enemy(enemy: Node) -> void:
	if enemy.has_method("take_damage"):
		enemy.take_damage(5)
	var old_scale := Engine.time_scale
	Engine.time_scale = HITSTOP_SCALE
	await get_tree().create_timer(HITSTOP_REAL_TIME, false, false, true).timeout
	Engine.time_scale = old_scale
	await get_tree().create_timer(AFTER_HIT_DELAY_REAL, false, false, true).timeout

func play_normal_anim() -> void:
	if not is_on_floor():
		_play_if_changed("Jump")
	elif abs(velocity.x) > 0.1:
		_play_if_changed("Run")
	else:
		_play_if_changed("Idle")

func _play_if_changed(name: StringName) -> void:
	if anim.animation != name:
		anim.play(name)

func _on_animated_sprite_2d_animation_finished() -> void:
	var name := anim.animation
	if name == "Attack":
		anim.play("After_Attack")
		return
	if name == "After_Attack":
		is_attacking = false
		play_normal_anim()
		return
	if name == "Take_Damage":
		is_attacking = false
		play_normal_anim()
		return


func take_damage(amount: int) -> void:
	
	play_take_damage()

func play_take_damage() -> void:
	is_attacking = true
	anim.play("Take_Damage")
