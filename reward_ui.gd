extends CanvasLayer

const RELIC_FALLBACK_ICON: Texture2D = preload("res://icon.svg")

@export var all_cards_db: Array[CardData] = []
@export var all_relics_db: Array[RelicData] = []
@export var reward_count: int = 3
@export_range(0.0, 1.0, 0.01) var normal_common_weight: float = 0.7
@export_range(0.0, 1.0, 0.01) var normal_uncommon_weight: float = 0.25
@export_range(0.0, 1.0, 0.01) var normal_rare_weight: float = 0.05
@export_range(0.0, 1.0, 0.01) var elite_common_weight: float = 0.3
@export_range(0.0, 1.0, 0.01) var elite_uncommon_weight: float = 0.45
@export_range(0.0, 1.0, 0.01) var elite_rare_weight: float = 0.25
@export_range(0.0, 1.0, 0.01) var normal_upgrade_chance: float = 0.12
@export_range(0.0, 1.0, 0.01) var elite_upgrade_chance: float = 0.33
@export_range(0.0, 1.0, 0.01) var normal_relic_reward_chance: float = 0.3

@onready var card_container: HBoxContainer = $VBoxContainer/HBoxContainer
@onready var root_vbox: VBoxContainer = $VBoxContainer
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

	_sync_databases_from_run_manager()

	_try_grant_relic_reward()
	_generate_card_rewards()


func _sync_databases_from_run_manager() -> void:
	var card_seen: Dictionary = {}
	for c in all_cards_db:
		if c == null:
			continue
		card_seen[c.id] = true
	for c in RunManager.get_available_card_pool():
		if c == null:
			continue
		if card_seen.has(c.id):
			continue
		all_cards_db.append(c)
		card_seen[c.id] = true

	var relic_seen: Dictionary = {}
	for r in all_relics_db:
		if r == null:
			continue
		relic_seen[r.id] = true
	for r in RunManager.get_available_relic_pool():
		if r == null:
			continue
		if relic_seen.has(r.id):
			continue
		all_relics_db.append(r)
		relic_seen[r.id] = true


func _try_grant_relic_reward() -> void:
	if all_relics_db.is_empty():
		return

	var guaranteed: bool = RunManager.current_enemy_is_elite
	var rolled: bool = guaranteed or randf() < normal_relic_reward_chance
	if not rolled:
		return

	var candidates: Array[RelicData] = []
	for relic in all_relics_db:
		if relic == null:
			continue
		if relic.id.strip_edges() == "":
			continue
		if relic.is_starter_relic:
			continue
		if relic.id != "" and RunManager.has_relic_id(relic.id):
			continue
		candidates.append(relic)
	if candidates.is_empty():
		return

	var picked: RelicData = candidates.pick_random() as RelicData
	if picked == null:
		return

	RunManager.add_relic(picked)
	_show_relic_notice(picked)


func _show_relic_notice(relic: RelicData) -> void:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(box)
	root_vbox.move_child(box, 1)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = relic.icon if relic.icon != null else RELIC_FALLBACK_ICON
	icon.tooltip_text = "%s\n%s" % [relic.get_display_name(), relic.description]
	box.add_child(icon)

	var label := Label.new()
	label.text = "Relic: %s" % relic.get_display_name()
	label.tooltip_text = "%s\n%s" % [relic.get_display_name(), relic.description]
	box.add_child(label)

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
		card_view.custom_minimum_size = Vector2(140, 180)
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
