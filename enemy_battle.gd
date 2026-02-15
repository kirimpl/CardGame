extends Node2D
const EnemyAppliedEffectRes = preload("res://Enemies/EnemyAppliedEffect.gd")

signal hit_player(target: Node)
signal apply_player_effects(payloads: Array)
signal turn_finished
signal died

var data: EnemyData
var hp: int
var max_hp: int
var damage: int
var current_defense: int = 0
var current_intent: EnemyData.Intent

# id -> { "data": EffectData, "dur": int, "stacks": int }
var effects: Dictionary = {}

const DEFAULT_EFFECT_PATHS: Dictionary = {
	"burn": "res://Cards/Effects/Burn.tres",
}

@export_group("Combat")
@export var floor_hp_scale: int = 4
@export var floor_damage_scale: int = 1
@export var elite_hp_multiplier: float = 1.5
@export var elite_damage_multiplier: float = 1.35
@export var early_normal_hp_bonus: int = 5
@export var early_normal_damage_bonus: int = 2
@export var early_normal_bonus_last_floor: int = 3
@export var defend_amount: int = 5
@export var buff_damage_amount: int = 2
@export var attack_lunge_offset: Vector2 = Vector2(60, 0)
@export var night_debuff_chance_bonus_percent: int = 10
@export var night_debuff_duration_bonus: int = 1

@export_group("Animation Settings")
@export var hit_frame: int = 2
@export var use_hitstop: bool = true
@export var hitstop_scale: float = 0.1
@export var hitstop_duration: float = 0.15
@export var return_speed: float = 0.2

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var intent_ui: Node2D = $IntentUI
@onready var intent_label: Label = $IntentUI/Label

var busy: bool = false


func setup(enemy_res: EnemyData, floor_level: int, is_elite: bool = false) -> void:
	if enemy_res == null:
		push_error("EnemyBattle.setup: enemy_res is null")
		return

	data = enemy_res
	if anim != null:
		anim.sprite_frames = data.sprite_frames
		anim.play("Idle")
		anim.frame = 0
		scale = Vector2(data.scale, data.scale)
		anim.flip_h = data.flip_h
		anim.position = data.battle_offset

	max_hp = data.base_hp + (floor_level * floor_hp_scale)
	if not is_elite and floor_level <= early_normal_bonus_last_floor:
		max_hp += early_normal_hp_bonus
	if is_elite:
		max_hp = int(round(float(max_hp) * elite_hp_multiplier))
	hp = max_hp
	damage = data.base_damage + (floor_level * floor_damage_scale)
	if not is_elite and floor_level <= early_normal_bonus_last_floor:
		damage += early_normal_damage_bonus
	if is_elite:
		damage = int(round(float(damage) * elite_damage_multiplier))
	if RunManager.is_night:
		max_hp = int(round(float(max_hp) * RunManager.night_enemy_hp_multiplier))
		hp = max_hp
		damage = int(round(float(damage) * RunManager.night_enemy_damage_multiplier))
	roll_intent()


func _ready() -> void:
	if intent_ui != null:
		intent_ui.visible = false


func roll_intent() -> void:
	if data == null or data.battle_actions.is_empty():
		current_intent = EnemyData.Intent.ATTACK
	else:
		current_intent = data.battle_actions.pick_random()
	_update_intent_visual()


func _update_intent_visual() -> void:
	if intent_ui == null or intent_label == null:
		return
	intent_ui.visible = true
	intent_label.text = ""
	match current_intent:
		EnemyData.Intent.ATTACK:
			intent_label.text = str(get_effective_attack_damage())
			intent_label.modulate = Color(1, 0.3, 0.3)
		EnemyData.Intent.DEFEND:
			intent_label.text = str(defend_amount)
			intent_label.modulate = Color(0.3, 0.6, 1)
		EnemyData.Intent.BUFF:
			intent_label.text = "!"
			intent_label.modulate = Color.GREEN
		EnemyData.Intent.DEBUFF:
			intent_label.text = "Debuff"
			intent_label.modulate = Color(0.82, 0.48, 1.0)


func tick_end_turn_effects() -> void:
	if hp <= 0:
		return
	await _tick_effects_for_phase(EffectData.TickWhen.END_TURN)


func _tick_effects_for_phase(phase: EffectData.TickWhen) -> void:
	var to_remove: Array[String] = []
	for id in effects.keys():
		var e: Dictionary = effects.get(id, {})
		var eff: EffectData = e.get("data") as EffectData
		var dur: int = int(e.get("dur", 0))
		var stacks: int = int(e.get("stacks", 0))
		if eff == null:
			to_remove.append(str(id))
			continue

		if eff.tick_when == phase and eff.is_damage_over_time:
			var dot: int = 0
			if eff.is_percent_of_current_hp_dot:
				dot = int(round(float(hp) * (float(eff.value) / 100.0)))
			else:
				dot = max(0, int(eff.value) * max(1, stacks))
			if dot > 0:
				hp = max(0, hp - dot)
				if hp > 0:
					await play_hit_anim()
				else:
					await play_death()
					return

		if eff.tick_when == phase and dur > 0:
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

	if intent_ui != null:
		intent_ui.visible = false

	await _tick_effects_for_phase(EffectData.TickWhen.START_TURN)
	if hp <= 0:
		busy = false
		return

	if _consume_stun_if_any():
		roll_intent()
		busy = false
		return

	match current_intent:
		EnemyData.Intent.ATTACK:
			await _attack_sequence(player_target)
		EnemyData.Intent.DEFEND:
			await _defend_sequence()
		EnemyData.Intent.BUFF:
			await _buff_sequence()
		EnemyData.Intent.DEBUFF:
			await _debuff_sequence(player_target)

	roll_intent()
	busy = false


func _consume_stun_if_any() -> bool:
	var e: Dictionary = effects.get("stun", {})
	if e.is_empty():
		return false
	var eff: EffectData = e.get("data") as EffectData
	if eff == null or eff.skip_turn_charges <= 0:
		return false
	var dur: int = int(e.get("dur", 0))
	if dur <= 0:
		return false
	dur -= 1
	if dur <= 0:
		effects.erase("stun")
	else:
		e["dur"] = dur
		effects["stun"] = e
	return true


func _attack_sequence(target: Node2D) -> void:
	if _roll_miss():
		await get_tree().create_timer(0.2).timeout
		_play_anim("Idle")
		return

	var start_pos: Vector2 = global_position
	var attack_pos: Vector2 = target.global_position + attack_lunge_offset

	var tween: Tween = create_tween()
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

	var return_tween: Tween = create_tween()
	return_tween.tween_property(self, "global_position", start_pos, return_speed)
	await return_tween.finished
	_play_anim("Idle")


func _roll_miss() -> bool:
	var miss_chance: int = get_total_miss_chance_percent()
	if miss_chance <= 0:
		return false
	return randi_range(1, 100) <= clampi(miss_chance, 0, 95)


func _defend_sequence() -> void:
	_play_anim("Idle")
	var t: Tween = create_tween()
	t.tween_property(self, "modulate", Color.CYAN, 0.2)
	t.tween_property(self, "modulate", Color.WHITE, 0.2)
	await t.finished
	current_defense += defend_amount
	_apply_configured_effects_to_self(data.defend_effects_on_self if data != null else [])


func _buff_sequence() -> void:
	damage += buff_damage_amount
	var t: Tween = create_tween()
	t.tween_property(self, "scale", scale * 1.2, 0.2)
	t.tween_property(self, "scale", scale, 0.2)
	await t.finished
	_apply_configured_effects_to_self(data.buff_effects_on_self if data != null else [])


func _debuff_sequence(_target: Node2D) -> void:
	_play_anim("Idle")
	var t: Tween = create_tween()
	t.tween_property(self, "modulate", Color(0.75, 0.45, 1.0, 1.0), 0.15)
	t.tween_property(self, "modulate", Color.WHITE, 0.15)
	await t.finished
	var payloads: Array[Dictionary] = _build_effect_payloads(data.debuff_effects_on_player if data != null else [])
	if RunManager.is_night and not payloads.is_empty():
		for i in range(payloads.size()):
			var payload: Dictionary = payloads[i]
			payload["duration"] = int(payload.get("duration", 1)) + max(0, night_debuff_duration_bonus)
			payloads[i] = payload
	if not payloads.is_empty():
		emit_signal("apply_player_effects", payloads)


func _build_effect_payloads(configs: Array[EnemyAppliedEffectRes]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cfg in configs:
		if cfg == null:
			continue
		var effect: EffectData = cfg.effect as EffectData
		if effect == null or effect.id == "":
			continue
		var roll: int = randi_range(1, 100)
		var chance: int = clampi(int(cfg.chance_percent), 0, 100)
		if RunManager.is_night:
			chance = clampi(chance + max(0, night_debuff_chance_bonus_percent), 0, 100)
		if roll > chance:
			continue
		out.append({
			"effect": effect,
			"duration": max(1, int(cfg.duration)),
			"stacks": max(1, int(cfg.stacks)),
		})
	return out


func _apply_configured_effects_to_self(configs: Array[EnemyAppliedEffectRes]) -> void:
	var payloads: Array[Dictionary] = _build_effect_payloads(configs)
	for payload in payloads:
		var effect: EffectData = payload.get("effect") as EffectData
		if effect == null:
			continue
		var duration: int = int(payload.get("duration", 1))
		var stacks: int = int(payload.get("stacks", 1))
		for _i in range(max(1, stacks)):
			apply_effect(effect, max(1, duration))


func apply_effect(effect_or_id: Variant, durability: int) -> void:
	if durability <= 0:
		return

	var data_any: Variant = null
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
		e["data"] = eff
		if eff.stackable:
			e["stacks"] = int(e.get("stacks", 0)) + 1
			e["dur"] = int(e.get("dur", 0)) + int(durability)
		else:
			e["stacks"] = 1
			e["dur"] = int(e.get("dur", 0)) + int(durability)
	effects[id] = e


func get_effects() -> Dictionary:
	var out: Dictionary = {}
	for id in effects.keys():
		var e: Dictionary = effects[id]
		out[id] = int(e.get("stacks", 0))
	return out


func get_effect_details() -> Dictionary:
	var out: Dictionary = {}
	for id in effects.keys():
		var e: Dictionary = effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			continue
		out[id] = {
			"title": eff.title,
			"description": eff.description,
			"stacks": int(e.get("stacks", 0)),
			"duration": int(e.get("dur", 0)),
		}
	return out


func get_effective_attack_damage() -> int:
	var mult: float = 1.0
	for id in effects.keys():
		var e: Dictionary = effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			continue
		mult *= maxf(0.0, eff.outgoing_damage_multiplier)
	return max(0, int(round(float(damage) * mult)))


func get_total_miss_chance_percent() -> int:
	var miss: int = 0
	for id in effects.keys():
		var e: Dictionary = effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			continue
		miss += max(0, eff.miss_chance_percent)
	return miss


func take_damage(amount: int) -> void:
	var dealt: int = max(0, amount)
	var incoming_mult: float = 1.0
	for id in effects.keys():
		var e: Dictionary = effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			continue
		incoming_mult *= eff.incoming_damage_multiplier
	dealt = max(0, int(round(float(dealt) * incoming_mult)))

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


func take_turn(player_node: Node, _player_block: int) -> void:
	await execute_turn(player_node)
