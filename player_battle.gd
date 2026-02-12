extends Node2D
signal hit_enemy(target: Node)

@export var hp: int = 40
@export var damage: int = 6

@export var hit_frame: int = 3
@export var attack_fps: float = 8.0            
@export var take_damage_fps: float = 10.0      
@export var take_damage_frames: int = 6       

@export var use_hitstop: bool = true
@export var hitstop_scale: float = 0.20
@export var hitstop_real_time: float = 0.12
@export var after_hit_delay_real: float = 0.10

var anim: AnimatedSprite2D
var hitboxes: Node2D

# === ССЫЛКА НА ТВОЙ РЕАЛЬНЫЙ ЩИТ ===
# Используем get_node("%Name"), это работает для узлов с % в дереве
@onready var shield_visual: Sprite2D = get_node("%ShieldVisual")

var busy := false
var facing_right := true

func _ready() -> void:
	anim = get_node_or_null("Player/Player/AnimatedSprite2D") as AnimatedSprite2D
	hitboxes = get_node_or_null("Player/Player/Hitboxes") as Node2D
	
	# === ПРОВЕРКА И СКРЫТИЕ ===
	if shield_visual:
		shield_visual.visible = false # Скрываем тот щит, что ты создал в редакторе
	

	if anim == null:
		push_error("PlayerBattle: AnimatedSprite2D не найден!")
		return
	
	_force_no_loop("Attack")
	_force_no_loop("Take_Damage")
	_force_no_loop("Death")
	_force_no_loop("After_Attack")
	play_idle()

# === УПРАВЛЕНИЕ ВИДИМОСТЬЮ ===
func toggle_shield(is_active: bool) -> void:
	if shield_visual == null: return
	
	if is_active:
		if not shield_visual.visible:
			shield_visual.visible = true
			shield_visual.modulate.a = 0.0
			var t = create_tween()
			t.tween_property(shield_visual, "modulate:a", 1.0, 0.3)
	else:
		if shield_visual.visible:
			var t = create_tween()
			t.tween_property(shield_visual, "modulate:a", 0.0, 0.2)
			await t.finished
			shield_visual.visible = false

# --- ОСТАЛЬНЫЕ ФУНКЦИИ БЕЗ ИЗМЕНЕНИЙ ---
func _force_no_loop(name: String) -> void:
	if anim == null or anim.sprite_frames == null: return
	if anim.sprite_frames.has_animation(name):
		anim.sprite_frames.set_animation_loop(name, false)

func face_towards(world_pos: Vector2) -> void:
	if anim == null: return
	facing_right = world_pos.x > global_position.x
	anim.flip_h = not facing_right
	if hitboxes: hitboxes.scale.x = 1 if facing_right else -1

func play_idle() -> void:
	if anim == null: return
	if not busy: _play("Idle")

func play_run() -> void:
	if anim == null: return
	if not busy: _play("Run")

func play_take_damage() -> void:
	if anim == null: return
	busy = true
	_play("Take_Damage")
	var dur: float = max(0.05, float(take_damage_frames) / max(1.0, take_damage_fps))
	await get_tree().create_timer(dur, false, false, true).timeout
	busy = false
	_play("Idle")

func play_death() -> void:
	if anim == null: return
	busy = true
	_play("Death")
	await get_tree().create_timer(0.6, false, false, true).timeout

func attack_sequence(target: Node2D) -> void:
	if busy or anim == null: return
	busy = true
	face_towards(target.global_position)
	_play("Attack")
	await _wait_hit_frame()
	if use_hitstop: await _hitstop()
	emit_signal("hit_enemy", target)
	await get_tree().create_timer(after_hit_delay_real, false, false, true).timeout
	if anim.sprite_frames and anim.sprite_frames.has_animation("After_Attack"):
		_play("After_Attack")
		await get_tree().create_timer(0.12, false, false, true).timeout
	busy = false
	_play("Idle")

func _wait_hit_frame() -> void:
	var max_wait := 1.0 
	var t0 := Time.get_ticks_msec()
	while anim and anim.animation == "Attack" and anim.frame < hit_frame:
		if Time.get_ticks_msec() - t0 > int(max_wait * 1000.0): break
		await anim.frame_changed

func _hitstop() -> void:
	var old := Engine.time_scale
	Engine.time_scale = hitstop_scale
	await get_tree().create_timer(hitstop_real_time, false, false, true).timeout
	Engine.time_scale = old

func _play(name: String) -> void:
	if anim == null: return
	if anim.sprite_frames and anim.sprite_frames.has_animation(name):
		if anim.animation != name: anim.play(name)
