extends CanvasLayer

@export var all_cards_db: Array[CardData] = []
@export var reward_count: int = 3
@export_range(0.0, 1.0, 0.01) var normal_common_weight: float = 0.7
@export_range(0.0, 1.0, 0.01) var normal_uncommon_weight: float = 0.25
@export_range(0.0, 1.0, 0.01) var normal_rare_weight: float = 0.05
@export_range(0.0, 1.0, 0.01) var elite_common_weight: float = 0.3
@export_range(0.0, 1.0, 0.01) var elite_uncommon_weight: float = 0.45
@export_range(0.0, 1.0, 0.01) var elite_rare_weight: float = 0.25
@export_range(0.0, 1.0, 0.01) var normal_upgrade_chance: float = 0.12
@export_range(0.0, 1.0, 0.01) var elite_upgrade_chance: float = 0.33

@onready var card_container: HBoxContainer = $VBoxContainer/HBoxContainer
@onready var skip_btn: Button = $VBoxContainer/SkipRewardButton
@onready var gold_label: Label = $VBoxContainer/GoldLabel if has_node("VBoxContainer/GoldLabel") else null
@onready var card_scene: PackedScene = preload("res://UI/CardView.tscn")

func _ready() -> void:
	get_tree().paused = true
	if skip_btn and not skip_btn.pressed.is_connected(_on_skip_pressed):
		skip_btn.pressed.connect(_on_skip_pressed)

	if RunManager.pending_gold > 0:
		RunManager.gold += RunManager.pending_gold
		if gold_label:
			gold_label.text = "Gold +%d" % int(RunManager.pending_gold)
		RunManager.pending_gold = 0

	_generate_card_rewards()

func _generate_card_rewards() -> void:
	if card_container == null:
		push_error("RewardUI: card_container not found")
		return

	if all_cards_db.is_empty():
		push_error("RewardUI: all_cards_db is empty")
		return

	for child in card_container.get_children():
		child.queue_free()

	var available_cards: Array[CardData] = all_cards_db.duplicate()
	var picked_ids: Dictionary = {}
	var cards_created: int = 0

	while cards_created < reward_count and not available_cards.is_empty():
		var picked_rarity: CardData.Rarity = _pick_rarity_for_reward(RunManager.current_enemy_is_elite)
		var card_data: CardData = _pick_card_of_rarity(available_cards, picked_rarity)
		if card_data == null:
			card_data = available_cards.pick_random() as CardData
		if card_data == null:
			break
		if picked_ids.has(card_data.id):
			available_cards.erase(card_data)
			continue

		var reward_card: CardData = _build_reward_card(card_data)
		var card_view: CardView = card_scene.instantiate() as CardView
		card_container.add_child(card_view)
		card_view.custom_minimum_size = Vector2(120, 160)
		card_view.use_physics = false
		card_view.setup(reward_card)
		if not card_view.played.is_connected(_on_card_selected):
			card_view.played.connect(_on_card_selected.bind(reward_card))

		picked_ids[card_data.id] = true
		available_cards.erase(card_data)
		cards_created += 1

func _pick_rarity_for_reward(is_elite_reward: bool) -> CardData.Rarity:
	var roll: float = randf()
	var common_w: float
	var uncommon_w: float
	var rare_w: float

	if is_elite_reward:
		common_w = elite_common_weight
		uncommon_w = elite_uncommon_weight
		rare_w = elite_rare_weight
	else:
		common_w = normal_common_weight
		uncommon_w = normal_uncommon_weight
		rare_w = normal_rare_weight

	var total: float = common_w + uncommon_w + rare_w
	if total <= 0.0:
		return CardData.Rarity.COMMON

	roll *= total
	if roll < rare_w:
		return CardData.Rarity.RARE

	roll -= rare_w
	if roll < uncommon_w:
		return CardData.Rarity.UNCOMMON

	return CardData.Rarity.COMMON

func _pick_card_of_rarity(pool: Array[CardData], rarity: CardData.Rarity) -> CardData:
	var filtered: Array[CardData] = []
	for card in pool:
		if card != null and card.rarity == rarity:
			filtered.append(card)

	if filtered.is_empty():
		return null

	return filtered.pick_random() as CardData

func _build_reward_card(template: CardData) -> CardData:
	var card_copy: CardData = template.duplicate(true) as CardData
	if card_copy == null:
		return template

	var upgrade_roll: float = randf()
	var chance: float = elite_upgrade_chance if RunManager.current_enemy_is_elite else normal_upgrade_chance
	card_copy.set_upgraded(upgrade_roll < chance)
	return card_copy

func _on_card_selected(data: CardData) -> void:
	var selected_copy: CardData = data.duplicate(true) as CardData
	if selected_copy == null:
		selected_copy = data
	RunManager.deck.append(selected_copy)
	_finish_reward()

func _on_skip_pressed() -> void:
	_finish_reward()

func _finish_reward() -> void:
	get_tree().paused = false
	RunManager.reward_claimed = true

	var level: Node = get_tree().current_scene
	if level.has_method("_on_chest_opened"):
		level._on_chest_opened()

	queue_free()
