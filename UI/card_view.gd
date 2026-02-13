extends Control
class_name CardView

signal card_hovered(card_view)
signal card_unhovered(card_view)
signal played

var card_data: CardData

@onready var title_label: Label = $CardNameBox/NameLabel
@onready var desc_label: Label = $CardBox/DescLabel
@onready var cost_label: Label = $CardCostBoxIcon/CostBackground/CardCost
@onready var main_icon: TextureRect = $CardRam/CardMainIcon
@onready var rarity_frame: TextureRect = get_node_or_null("CardRarityRam")

@export var icon_attack: Texture2D
@export var icon_attack_fire: Texture2D
@export var icon_defense: Texture2D
@export var icon_buff: Texture2D
@export var rarity_common_frame: Texture2D = preload("res://Cards/RarityRam/Common.tres")
@export var rarity_uncommon_frame: Texture2D = preload("res://Cards/RarityRam/uncommon.tres")
@export var rarity_rare_frame: Texture2D = preload("res://Cards/RarityRam/Rare.tres")
@export var rarity_legendary_frame: Texture2D = preload("res://Cards/RarityRam/Legendary.tres")

var target_position: Vector2 = Vector2.ZERO
var target_rotation: float = 0.0
var target_scale: Vector2 = Vector2(1, 1)
var lerp_speed: float = 15.0
var is_hovered: bool = false
var use_physics: bool = true
var hover_tween: Tween = null

@export_group("Hover Anim")
@export var reward_hover_scale: float = 1.08
@export var reward_hover_time: float = 0.12
@export var reward_hover_brightness: float = 1.08

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pivot_offset = Vector2(size.x / 2.0, size.y)
	_update_rarity_frame()
	if card_data:
		_update_visuals()

func setup(data: CardData) -> void:
	card_data = data
	if is_node_ready():
		_update_visuals()

func _update_visuals() -> void:
	if card_data == null:
		return

	if title_label:
		title_label.text = card_data.get_display_title()

	if desc_label:
		var d: String = card_data.get_description()
		if card_data.has_effect():
			var eff_id: String = card_data.get_effect_id()
			var eff_data: EffectData = card_data.get_effect()
			var eff_title: String = eff_data.title if eff_data else eff_id
			var eff_dur: int = card_data.get_effect_durability()
			if eff_id != "" and eff_dur > 0:
				d += "\nEffect: %s (%d turns)" % [eff_title, eff_dur]
		if card_data.is_upgraded():
			d += "\n[Upgraded]"
		desc_label.text = d

	if cost_label:
		cost_label.text = str(card_data.get_cost())

	_update_rarity_frame()
	_update_main_icon()

func _update_main_icon() -> void:
	if main_icon == null or card_data == null:
		return

	var t: int = int(card_data.get_card_type()) if card_data.has_method("get_card_type") else 0
	main_icon.modulate = Color.WHITE
	match t:
		CardData.CardType.ATTACK:
			if card_data.has_method("is_attack_with_fire") and card_data.is_attack_with_fire():
				main_icon.texture = icon_attack_fire if icon_attack_fire != null else icon_attack
				if icon_attack_fire == null:
					main_icon.modulate = Color(1.0, 0.55, 0.25, 1.0)
			else:
				main_icon.texture = icon_attack
		CardData.CardType.DEFENSE:
			main_icon.texture = icon_defense
		CardData.CardType.BUFF:
			main_icon.texture = icon_buff
		_:
			pass

func _update_rarity_frame() -> void:
	if rarity_frame == null:
		return

	if card_data == null:
		rarity_frame.texture = rarity_common_frame
		return

	match card_data.rarity:
		CardData.Rarity.LEGENDARY:
			rarity_frame.texture = rarity_legendary_frame
		CardData.Rarity.RARE:
			rarity_frame.texture = rarity_rare_frame
		CardData.Rarity.UNCOMMON:
			rarity_frame.texture = rarity_uncommon_frame
		_:
			rarity_frame.texture = rarity_common_frame

func _process(delta: float) -> void:
	if use_physics:
		position = position.lerp(target_position, lerp_speed * delta)
		rotation_degrees = lerp(rotation_degrees, target_rotation, lerp_speed * delta)
		scale = scale.lerp(target_scale, lerp_speed * delta)

func _on_mouse_entered() -> void:
	is_hovered = true
	if not use_physics:
		_play_reward_hover_anim(true)
	emit_signal("card_hovered", self)

func _on_mouse_exited() -> void:
	is_hovered = false
	if not use_physics:
		_play_reward_hover_anim(false)
	emit_signal("card_unhovered", self)

func _gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("played")

func _play_reward_hover_anim(hovered: bool) -> void:
	if hover_tween != null and hover_tween.is_running():
		hover_tween.kill()

	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_QUAD)
	hover_tween.set_ease(Tween.EASE_OUT if hovered else Tween.EASE_IN)

	var target_scale_value: Vector2 = Vector2.ONE * reward_hover_scale if hovered else Vector2.ONE
	var target_modulate: Color = Color(reward_hover_brightness, reward_hover_brightness, reward_hover_brightness, 1.0) if hovered else Color.WHITE

	hover_tween.parallel().tween_property(self, "scale", target_scale_value, reward_hover_time)
	hover_tween.parallel().tween_property(self, "modulate", target_modulate, reward_hover_time)
