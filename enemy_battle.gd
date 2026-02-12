extends Node2D

signal hit_player(target: Node)
signal turn_finished
signal died

var data: EnemyData
var hp: int
var max_hp: int
var damage: int
var current_defense: int = 0
var current_intent: EnemyData.Intent

# Активные эффекты:
# id -> { "data": EffectData, "dur": int, "stacks": int }
var effects: Dictionary = {}

# Фолбэки на случай старых вызовов apply_effect("burn", dur)
const DEFAULT_EFFECT_PATHS: Dictionary = {
	"burn": "res://Cards/Effects/Burn.tres",
}

@export_group("Combat")
@export var floor_hp_scale: int = 3
@export var floor_damage_scale: int = 1
@export var elite_hp_multiplier: float = 1.5
@export var elite_damage_multiplier: float = 1.35
@export var defend_amount: int = 5
@export var buff_damage_amount: int = 2
@export var attack_lunge_offset: Vector2 = Vector2(60, 0)

@export_group("Animation Settings")
@export var hit_frame: int = 2
@export var use_hitstop: bool = true
@export var hitstop_scale: float = 0.1
@export var hitstop_duration: float = 0.15
@export var return_speed: float = 0.2

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var intent_ui: Node2D = $IntentUI
@onready var intent_label: Label = $IntentUI/Label

var busy := false


func setup(enemy_res: EnemyData, floor_level: int, is_elite: bool = false) -> void:
	if enemy_res == null:
		push_error("EnemyBattle.setup: enemy_res is null")
		return

	data = enemy_res
	if anim:
		anim.sprite_frames = data.sprite_frames
		# Force idle playback after swapping SpriteFrames (needed for some enemy sets).
		anim.play("Idle")
		anim.frame = 0

		scale = Vector2(data.scale, data.scale)
		anim.flip_h = data.flip_h
		anim.position = data.battle_offset

	max_hp = data.base_hp + (floor_level * floor_hp_scale)
	if is_elite:
		max_hp = int(round(float(max_hp) * elite_hp_multiplier))
	hp = max_hp
	damage = data.base_damage + (floor_level * floor_damage_scale)
	if is_elite:
		damage = int(round(float(damage) * elite_damage_multiplier))
	roll_intent()


func _ready() -> void:
	if intent_ui:
		intent_ui.visible = false


func roll_intent() -> void:
	if data == null:
		current_intent = EnemyData.Intent.ATTACK
		_update_intent_visual()
		return

	if data.battle_actions.is_empty():
		current_intent = EnemyData.Intent.ATTACK
	else:
		current_intent = data.battle_actions.pick_random()
	_update_intent_visual()


func _update_intent_visual() -> void:
	if not intent_ui or not intent_label:
		return
	intent_ui.visible = true
	intent_label.text = ""
	match current_intent:
		EnemyData.Intent.ATTACK:
			intent_label.text = str(damage)
			intent_label.modulate = Color(1, 0.3, 0.3)
		EnemyData.Intent.DEFEND:
			intent_label.text = str(defend_amount)
			intent_label.modulate = Color(0.3, 0.6, 1)
		EnemyData.Intent.BUFF:
			intent_label.text = "!"
			intent_label.modulate = Color.GREEN


func tick_end_turn_effects() -> void:
	if hp <= 0:
		return

	var to_remove: Array[String] = []

	for id in effects.keys():
		var e: Dictionary = effects.get(id, {})
		var eff: EffectData = e.get("data") as EffectData
		var dur: int = int(e.get("dur", 0))
		var stacks: int = int(e.get("stacks", 0))

		if eff == null or dur <= 0:
			to_remove.append(str(id))
			continue

		# Тик на End Turn
		if eff.tick_when == EffectData.TickWhen.END_TURN:
			if eff.is_damage_over_time:
				# Урон растёт от стаков только для damage эффектов
				var dmg: int = max(0, int(eff.value) * max(1, stacks))
				if dmg > 0:
					hp -= dmg
					hp = max(0, hp)

					if hp > 0:
						await play_hit_anim()
					else:
						await play_death()
						return

		# Длительность уменьшается каждый End Turn
		dur -= 1
		e["dur"] = dur
		effects[id] = e
		if dur <= 0:
			to_remove.append(str(id))

	for rid in to_remove:
		effects.erase(rid)


func execute_turn(player_target: Node2D) -> void:
	busy = true
	if hp <= 0:
		busy = false
		return

	if intent_ui:
		intent_ui.visible = false

	match current_intent:
		EnemyData.Intent.ATTACK:
			await _attack_sequence(player_target)
		EnemyData.Intent.DEFEND:
			await _defend_sequence()
		EnemyData.Intent.BUFF:
			await _buff_sequence()

	roll_intent()
	busy = false


func _attack_sequence(target: Node2D) -> void:
	var start_pos: Vector2 = global_position
	var attack_pos: Vector2 = target.global_position + attack_lunge_offset

	var tween := create_tween()
	tween.tween_property(self, "global_position", attack_pos, 0.2).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	_play_anim("Attack")
	await _wait_hit_frame()

	if use_hitstop:
		var old_scale: float = Engine.time_scale
		Engine.time_scale = hitstop_scale
		await get_tree().create_timer(hitstop_duration * hitstop_scale).timeout
		Engine.time_scale = old_scale

	emit_signal("hit_player", target)

	await get_tree().create_timer(0.2).timeout

	var return_tween := create_tween()
	return_tween.tween_property(self, "global_position", start_pos, return_speed)
	await return_tween.finished

	_play_anim("Idle")


func _defend_sequence() -> void:
	_play_anim("Idle")
	var t := create_tween()
	t.tween_property(self, "modulate", Color.CYAN, 0.2)
	t.tween_property(self, "modulate", Color.WHITE, 0.2)
	await t.finished
	current_defense += defend_amount


func _buff_sequence() -> void:
	damage += buff_damage_amount
	var t := create_tween()
	t.tween_property(self, "scale", scale * 1.2, 0.2)
	t.tween_property(self, "scale", scale, 0.2)
	await t.finished


func apply_effect(effect_or_id: Variant, durability: int) -> void:
	# Поддерживает оба варианта:
	#  - apply_effect(EffectData, dur)
	#  - apply_effect("burn", dur)  (старый код)
	if durability <= 0:
		return

	var data_any = null
	var id: String = ""

	if effect_or_id is EffectData:
		data_any = effect_or_id
		id = (data_any as EffectData).id
	elif typeof(effect_or_id) == TYPE_STRING:
		id = str(effect_or_id)
		var p: String = str(DEFAULT_EFFECT_PATHS.get(id, ""))
		if p != "":
			data_any = load(p)

	if data_any == null or id == "":
		return

	var eff: EffectData = data_any as EffectData
	if eff == null:
		return
	if id == "":
		id = eff.id
	if id == "":
		return

	var e: Dictionary = effects.get(id, {})
	if e.is_empty():
		e = {"data": eff, "dur": int(durability), "stacks": 1}
	else:
		# Все эффекты стакуются.
		e["data"] = eff
		e["dur"] = int(e.get("dur", 0)) + int(durability)
		e["stacks"] = int(e.get("stacks", 0)) + 1

	# Сохранить
	effects[id] = e


func get_effects() -> Dictionary:
	# Для UI отдаём стаки, чтобы было понятно "насколько сильно".
	var out: Dictionary = {}
	for id in effects.keys():
		var e: Dictionary = effects[id]
		out[id] = int(e.get("stacks", 0))
	return out


func take_damage(amount: int) -> void:
	var dealt: int = max(0, amount)
	if current_defense > 0:
		var absorbed: int = min(current_defense, dealt)
		current_defense -= absorbed
		dealt -= absorbed

	hp = max(0, hp - dealt)
	if hp <= 0:
		await play_death()
	elif dealt > 0:
		await play_hit_anim()


func play_hit_anim() -> void:
	busy = true
	_play_anim("Take_Damage")
	if anim.sprite_frames and anim.sprite_frames.has_animation("Take_Damage"):
		await anim.animation_finished
	busy = false
	_play_anim("Idle")


func play_death() -> void:
	busy = true
	_play_anim("Death")
	if anim.sprite_frames and anim.sprite_frames.has_animation("Death"):
		await anim.animation_finished
	else:
		await get_tree().create_timer(0.6).timeout
	busy = false
	emit_signal("died")
	queue_free()


func _play_anim(name: String) -> void:
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation(name):
		if anim.animation != name or not anim.is_playing():
			anim.play(name)


func _wait_hit_frame() -> void:
	while anim.frame < hit_frame and anim.is_playing() and anim.animation == "Attack":
		await get_tree().process_frame


# compatibility wrapper
func take_turn(player_node: Node, _player_block: int) -> void:
	await execute_turn(player_node)
