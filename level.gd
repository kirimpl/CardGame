extends Node2D

const RELIC_FALLBACK_ICON: Texture2D = preload("res://icon.svg")

var fight_started: bool = false
var enemy: Node = null
var is_rest_room: bool = false
var active_station_id: String = ""
var campfire_used: bool = false
var popup_mode: String = ""
var active_event_room: bool = false
var forced_room_type: String = ""

@export var enemy_overworld_scene: PackedScene = preload("res://Mob/EnemyOverworld.tscn")
@export var card_view_scene: PackedScene = preload("res://UI/CardView.tscn")
@export var rest_config: RestConfig = preload("res://Rest/Data/DefaultRestConfig.tres")
@export_range(0.0, 1.0, 0.01) var event_room_chance_early: float = 0.08
@export_range(0.0, 1.0, 0.01) var event_room_chance_mid: float = 0.18
@export_range(0.0, 1.0, 0.01) var event_room_chance_late: float = 0.14

@onready var mobs_root: Node2D = $Mobs
@onready var enemy_spawn: Node2D = $Mobs/EnemySpawn
@onready var chest: Area2D = $Chest
@onready var portal: Area2D = $Portal
@onready var player: Node2D = $Player/Player
@onready var hp_label: Label = get_node_or_null("HUD/HPLabel")
@onready var gold_label: Label = get_node_or_null("HUD/GoldLabel")
@onready var floor_label: Label = get_node_or_null("HUD/FloorLabel")

var day_label: Label = null
var interact_label: Label = null
var rest_stations_root: Node2D = null
var station_prompts: Dictionary = {}

var popup_overlay: Control = null
var popup_panel: PanelContainer = null
var popup_title: Label = null
var popup_body: VBoxContainer = null
var popup_close_btn: Button = null

var merchant_card_offers: Array[Dictionary] = []
var merchant_relic_offers: Array[Dictionary] = []

var relic_panel: PanelContainer = null
var relic_icons_row: HBoxContainer = null
var relic_tooltip: PanelContainer = null
var relic_tooltip_title: Label = null
var relic_tooltip_desc: Label = null
var relic_signature_cached: String = ""
var save_exit_btn: Button = null


func _ready() -> void:
	RunManager.bootstrap_starting_relics_from_fight_scene()
	RunManager.apply_starting_relics()

	if player and ("hp" in player):
		RunManager.current_hp = int(player.hp)

	_setup_day_label()
	_setup_interact_label()
	_setup_popup_ui()
	_setup_relic_panel()
	_setup_save_exit_button()
	forced_room_type = RunManager.consume_forced_room_type()
	if forced_room_type != "":
		RunManager.forced_room_type = forced_room_type

	if player.has_signal("hit_enemy") and not player.hit_enemy.is_connected(_on_player_hit_enemy):
		player.hit_enemy.connect(_on_player_hit_enemy)

	is_rest_room = (forced_room_type == RunManager.ROOM_REST) or RunManager.is_rest_floor(RunManager.current_floor)
	if is_rest_room:
		_setup_rest_state()
	elif RunManager.returning_from_fight:
		_setup_victory_state()
	else:
		_setup_battle_state()

	_update_hud()


func _setup_battle_state() -> void:
	active_event_room = false
	if forced_room_type == RunManager.ROOM_MERCHANT:
		RunManager.forced_room_type = ""
		_setup_rest_state()
		_open_merchant_popup()
		return
	if forced_room_type == RunManager.ROOM_EVENT:
		RunManager.forced_room_type = ""
		active_event_room = true
		_open_random_event_now()
		chest.hide()
		chest.monitoring = false
		portal.show()
		portal.monitoring = true
		return
	if forced_room_type == RunManager.ROOM_TREASURE:
		RunManager.forced_room_type = ""
		chest.show()
		chest.monitoring = true
		portal.hide()
		portal.monitoring = false
		RunManager.reward_claimed = false
		return
	if forced_room_type == "" and _try_start_event_room():
		active_event_room = true
		chest.hide()
		chest.monitoring = false
		portal.show()
		portal.monitoring = true
		return
	_spawn_random_enemy()
	chest.hide()
	chest.monitoring = false
	portal.hide()
	portal.monitoring = false


func _open_random_event_now() -> void:
	var roll: int = RunManager.rolli_range_run(0, 2)
	match roll:
		0:
			_open_event_forgotten_shrine()
		1:
			_open_event_cursed_totem()
		_:
			_open_event_traveling_sage()


func _setup_victory_state() -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()

	if RunManager.reward_claimed:
		chest.hide()
		chest.monitoring = false
		portal.show()
		portal.monitoring = true
	else:
		chest.show()
		chest.monitoring = true
		portal.hide()
		portal.monitoring = false


func _setup_rest_state() -> void:
	RunManager.forced_room_type = ""
	if is_instance_valid(enemy):
		enemy.queue_free()
	enemy = null

	chest.hide()
	chest.monitoring = false
	portal.show()
	portal.monitoring = true

	if RunManager.pending_gold > 0:
		RunManager.gold += RunManager.pending_gold
		RunManager.pending_gold = 0

	_create_rest_stations()
	_roll_merchant_offers()


func _create_rest_stations() -> void:
	rest_stations_root = Node2D.new()
	rest_stations_root.name = "RestStations"
	add_child(rest_stations_root)

	_create_rest_station("Campfire", Vector2(540.0, 618.0), Color(1.0, 0.55, 0.2, 1.0), "E - Campfire")
	_create_rest_station("Smith", Vector2(760.0, 618.0), Color(0.65, 0.72, 0.78, 1.0), "E - Smith")
	_create_rest_station("Merchant", Vector2(980.0, 618.0), Color(0.35, 0.85, 0.45, 1.0), "E - Merchant")


func _create_rest_station(station_name: String, world_pos: Vector2, tint: Color, prompt: String) -> void:
	var area: Area2D = Area2D.new()
	area.name = station_name
	area.position = world_pos
	area.collision_layer = 0
	area.collision_mask = 1
	rest_stations_root.add_child(area)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(74.0, 90.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -38.0)
	area.add_child(shape)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = RELIC_FALLBACK_ICON
	sprite.modulate = tint
	sprite.position = Vector2(0.0, -46.0)
	sprite.scale = Vector2(0.6, 0.6)
	area.add_child(sprite)

	var label: Label = Label.new()
	label.text = station_name
	label.position = Vector2(-52.0, -108.0)
	label.add_theme_font_size_override("font_size", 15)
	area.add_child(label)

	area.body_entered.connect(_on_station_body_entered.bind(station_name))
	area.body_exited.connect(_on_station_body_exited.bind(station_name))
	station_prompts[station_name] = prompt


func _spawn_random_enemy() -> void:
	if enemy_overworld_scene == null:
		push_error("Level: enemy_overworld_scene is not assigned")
		return

	if is_instance_valid(enemy):
		enemy.queue_free()
		enemy = null

	var picked: EnemyData = RunManager.pick_enemy_for_floor()
	if picked == null:
		push_error("Level: failed to pick EnemyData")
		return
	RunManager.mark_enemy_seen(picked.resource_path)
	RunManager.forced_room_type = ""

	enemy = enemy_overworld_scene.instantiate()
	enemy.global_position = enemy_spawn.global_position

	if "data" in enemy:
		enemy.data = picked

	mobs_root.add_child(enemy)
	if enemy.has_signal("start_battle") and not enemy.start_battle.is_connected(_on_enemy_start_battle):
		enemy.start_battle.connect(_on_enemy_start_battle)


func _on_enemy_start_battle(enemy_data: EnemyData) -> void:
	start_fight_logic(enemy_data, GameState.Starter.ENEMY)


func _on_player_hit_enemy(target_node: Node) -> void:
	if is_rest_room or not is_instance_valid(enemy):
		return
	if target_node == enemy or target_node.get_parent() == enemy:
		var data_to_use: EnemyData = null
		if "data" in enemy:
			data_to_use = enemy.data
		if data_to_use != null:
			start_fight_logic(data_to_use, GameState.Starter.PLAYER)


func start_fight_logic(enemy_data: EnemyData, starter: GameState.Starter) -> void:
	if fight_started:
		return
	fight_started = true
	RunManager.current_enemy_data = enemy_data
	GameState.starter = starter
	GameState.return_scene = "res://level.tscn"
	GameState.spawn_pos = player.global_position
	call_deferred("_change_scene_safe")


func _change_scene_safe() -> void:
	get_tree().change_scene_to_file("res://fight.tscn")


func _on_portal_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		RunManager.next_floor()


func _try_start_event_room() -> bool:
	if RunManager.current_floor <= 1:
		return false
	var chance: float = _get_event_room_chance_for_floor(RunManager.current_floor)
	if RunManager.rollf_run() >= chance:
		return false
	var roll: int = RunManager.rolli_range_run(0, 2)
	match roll:
		0:
			_open_event_forgotten_shrine()
		1:
			_open_event_cursed_totem()
		_:
			_open_event_traveling_sage()
	return true


func _get_event_room_chance_for_floor(floor: int) -> float:
	if floor <= 3:
		return event_room_chance_early
	if floor <= 7:
		return event_room_chance_mid
	return event_room_chance_late


func _open_event_forgotten_shrine() -> void:
	RunManager.mark_event_seen("forgotten_shrine")
	_show_popup_shell("Event: Forgotten Shrine")
	var info: Label = Label.new()
	info.text = "A ruined shrine hums with old power."
	popup_body.add_child(info)
	_add_event_choice("Offer Blood (-10 HP, gain Rare card)", Callable(self, "_event_shrine_offer_blood"))
	_add_event_choice("Pray (remove 1 Curse from deck)", Callable(self, "_event_shrine_cleanse"))
	_add_event_choice("Leave", Callable(self, "_close_popup"))


func _event_shrine_offer_blood() -> void:
	RunManager.current_hp = max(1, RunManager.current_hp - 10)
	var card: CardData = _pick_reward_card_by_rarity(CardData.Rarity.RARE)
	if card != null:
		RunManager.deck.append(card)
	_show_popup_notice("You gained power from blood.")


func _event_shrine_cleanse() -> void:
	var removed: bool = _remove_one_curse_from_deck()
	_show_popup_notice("Curse removed." if removed else "No curses to remove.")


func _open_event_cursed_totem() -> void:
	RunManager.mark_event_seen("cursed_totem")
	_show_popup_shell("Event: Cursed Totem")
	var info: Label = Label.new()
	info.text = "A totem offers strength at a cost."
	popup_body.add_child(info)
	_add_event_choice("Accept (gain relic, add curse)", Callable(self, "_event_totem_accept"))
	_add_event_choice("Ignore", Callable(self, "_close_popup"))


func _event_totem_accept() -> void:
	var relic: RelicData = _pick_random_relic_reward()
	if relic != null:
		RunManager.add_relic(relic)
	_add_random_curse_to_deck()
	_show_popup_notice("You took the totem's bargain.")


func _open_event_traveling_sage() -> void:
	RunManager.mark_event_seen("traveling_sage")
	_show_popup_shell("Event: Traveling Sage")
	var info: Label = Label.new()
	info.text = "A sage offers to train your deck."
	popup_body.add_child(info)
	_add_event_choice("Pay 40 gold: upgrade random card", Callable(self, "_event_sage_upgrade"))
	_add_event_choice("Pay 20 gold: remove 1 curse", Callable(self, "_event_sage_cleanse"))
	_add_event_choice("Decline", Callable(self, "_close_popup"))


func _event_sage_upgrade() -> void:
	if RunManager.gold < 40:
		_show_popup_notice("Not enough gold.")
		return
	RunManager.gold -= 40
	var upgraded: bool = _upgrade_random_non_upgraded_card()
	_show_popup_notice("A card was upgraded." if upgraded else "No upgradable cards.")


func _event_sage_cleanse() -> void:
	if RunManager.gold < 20:
		_show_popup_notice("Not enough gold.")
		return
	RunManager.gold -= 20
	var removed: bool = _remove_one_curse_from_deck()
	_show_popup_notice("Curse removed." if removed else "No curses to remove.")


func _add_event_choice(text: String, cb: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.pressed.connect(cb)
	popup_body.add_child(btn)


func _pick_reward_card_by_rarity(rarity: CardData.Rarity) -> CardData:
	var candidates: Array[CardData] = []
	for c in RunManager.get_available_card_pool():
		if c == null:
			continue
		if not c.can_appear_in_rewards:
			continue
		if c.rarity != rarity:
			continue
		candidates.append(c)
	if candidates.is_empty():
		return null
	var chosen: CardData = RunManager.pick_from_array_run(candidates) as CardData
	if chosen == null:
		return null
	var copy: CardData = chosen.duplicate(true) as CardData
	return copy if copy != null else chosen


func _pick_random_relic_reward() -> RelicData:
	var candidates: Array[RelicData] = []
	for relic in RunManager.get_available_relic_pool():
		if relic == null:
			continue
		if relic.id != "" and RunManager.has_relic_id(relic.id):
			continue
		candidates.append(relic)
	if candidates.is_empty():
		return null
	return RunManager.pick_from_array_run(candidates) as RelicData


func _add_random_curse_to_deck() -> void:
	var paths: PackedStringArray = PackedStringArray([
		"res://Cards/Data/Curse/Doubt.tres",
		"res://Cards/Data/Curse/Regret.tres",
	])
	var picked_path: String = paths[RunManager.rolli_range_run(0, paths.size() - 1)]
	var res: Resource = load(picked_path)
	if res is CardData:
		var card_template: CardData = res as CardData
		var copy: CardData = card_template.duplicate(true) as CardData
		RunManager.deck.append(copy if copy != null else card_template)


func _remove_one_curse_from_deck() -> bool:
	for i in range(RunManager.deck.size()):
		var c: CardData = RunManager.deck[i]
		if c != null and c.is_curse:
			RunManager.deck.remove_at(i)
			return true
	return false


func _upgrade_random_non_upgraded_card() -> bool:
	var candidates: Array[int] = []
	for i in range(RunManager.deck.size()):
		var c: CardData = RunManager.deck[i]
		if c == null:
			continue
		if c.is_upgraded():
			continue
		candidates.append(i)
	if candidates.is_empty():
		return false
	var idx: int = int(RunManager.pick_from_array_run(candidates))
	RunManager.deck[idx].set_upgraded(true)
	return true


func _on_chest_opened() -> void:
	chest.hide()
	chest.monitoring = false
	portal.show()
	portal.monitoring = true


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not is_rest_room:
		return
	if popup_overlay != null and popup_overlay.visible:
		return
	if not event.is_action_pressed("interact"):
		return

	match active_station_id:
		"Campfire":
			_use_campfire()
		"Smith":
			_open_smith_popup()
		"Merchant":
			_open_merchant_popup()


func _on_station_body_entered(body: Node2D, station_name: String) -> void:
	if not _is_player(body):
		return
	active_station_id = station_name
	if interact_label != null:
		interact_label.text = str(station_prompts.get(station_name, "E - Interact"))
		interact_label.visible = true


func _on_station_body_exited(body: Node2D, station_name: String) -> void:
	if not _is_player(body):
		return
	if active_station_id == station_name:
		active_station_id = ""
	if interact_label != null:
		interact_label.visible = false


func _is_player(body: Node) -> bool:
	return body != null and (body.name == "Player" or body.is_in_group("Player"))


func _use_campfire() -> void:
	if campfire_used:
		_show_popup_notice("Campfire already used on this floor.")
		return

	var base_pct: float = RunManager.campfire_heal_percent
	var bonus_pct: float = RunManager.get_campfire_heal_bonus_percent()
	var healed: int = RunManager.heal_from_campfire()
	RunManager.add_run_stat("healing_done", float(healed))
	RunManager.log_combat("Campfire healed %d HP on floor %d" % [healed, RunManager.current_floor])
	RunManager.toggle_day_night()
	campfire_used = true
	_update_hud()
	_show_popup_notice(
		"Recovered %d HP (%.0f%% + %.0f%%). Time switched to %s." % [
			healed,
			base_pct * 100.0,
			bonus_pct * 100.0,
			_time_of_day_text(),
		]
	)


func _roll_merchant_offers() -> void:
	if not merchant_card_offers.is_empty() or not merchant_relic_offers.is_empty():
		return

	var card_pool: Array[CardData] = []
	for pool_card in RunManager.get_available_card_pool():
		if pool_card == null:
			continue
		if not pool_card.can_appear_in_merchant:
			continue
		card_pool.append(pool_card)
	var used_card_ids: Dictionary = {}
	while merchant_card_offers.size() < rest_config.merchant_card_offer_count and not card_pool.is_empty():
		var picked: CardData = RunManager.pick_from_array_run(card_pool) as CardData
		if picked == null:
			break
		if used_card_ids.has(picked.id):
			card_pool.erase(picked)
			continue
		used_card_ids[picked.id] = true
		var card_copy: CardData = picked.duplicate(true) as CardData
		if card_copy == null:
			card_copy = picked
		merchant_card_offers.append({"card": card_copy, "price": _get_card_price(card_copy), "bought": false})
		card_pool.erase(picked)

	var relic_pool: Array[RelicData] = []
	for relic_res in RunManager.get_available_relic_pool():
		if relic_res == null:
			continue
		if relic_res.id != "" and RunManager.has_relic_id(relic_res.id):
			continue
		relic_pool.append(relic_res)

	while merchant_relic_offers.size() < rest_config.merchant_relic_offer_count and not relic_pool.is_empty():
		var picked_relic: RelicData = RunManager.pick_from_array_run(relic_pool) as RelicData
		if picked_relic == null:
			break
		var relic_copy: RelicData = picked_relic.duplicate(true) as RelicData
		if relic_copy == null:
			relic_copy = picked_relic
		merchant_relic_offers.append({"relic": relic_copy, "price": _get_relic_price(relic_copy), "bought": false})
		relic_pool.erase(picked_relic)


func _get_card_price(card: CardData) -> int:
	var base: int = rest_config.merchant_card_price_common
	match card.rarity:
		CardData.Rarity.UNCOMMON:
			base = rest_config.merchant_card_price_uncommon
		CardData.Rarity.RARE:
			base = rest_config.merchant_card_price_rare
		CardData.Rarity.LEGENDARY:
			base = rest_config.merchant_card_price_legendary
	return RunManager.apply_merchant_discount(base)


func _get_relic_price(relic: RelicData) -> int:
	var base: int = rest_config.merchant_relic_price_common
	match relic.rarity:
		RelicData.RelicRarity.UNCOMMON:
			base = rest_config.merchant_relic_price_uncommon
		RelicData.RelicRarity.RARE:
			base = rest_config.merchant_relic_price_rare
		RelicData.RelicRarity.LEGENDARY:
			base = rest_config.merchant_relic_price_legendary
	return RunManager.apply_merchant_discount(base)


func _open_merchant_popup() -> void:
	popup_mode = "merchant"
	_show_popup_shell("Merchant")

	var discount_pct: float = RunManager.get_merchant_discount_percent() * 100.0
	var purge_price: int = RunManager.get_merchant_purge_price(
		rest_config.merchant_purge_price_base,
		rest_config.merchant_purge_price_increment
	)
	var gold_info: Label = Label.new()
	gold_info.text = "Gold: %d   |   Merchant discount: %.0f%%   |   Purge: %d" % [int(RunManager.gold), discount_pct, purge_price]
	popup_body.add_child(gold_info)

	var card_header: Label = Label.new()
	card_header.text = "Cards"
	card_header.add_theme_font_size_override("font_size", 18)
	popup_body.add_child(card_header)

	var cards_row: HBoxContainer = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 14)
	popup_body.add_child(cards_row)

	for i in range(merchant_card_offers.size()):
		var offer: Dictionary = merchant_card_offers[i]
		var card: CardData = offer.get("card") as CardData
		var price: int = int(offer.get("price", 0))
		var bought: bool = bool(offer.get("bought", false))
		if card == null:
			continue

		var col: VBoxContainer = VBoxContainer.new()
		col.custom_minimum_size = Vector2(146.0, 260.0)
		cards_row.add_child(col)

		var card_view: CardView = card_view_scene.instantiate() as CardView
		if card_view != null:
			card_view.use_physics = false
			card_view.custom_minimum_size = Vector2(140.0, 190.0)
			card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_view.setup(card)
			col.add_child(card_view)

		var buy_btn: Button = Button.new()
		buy_btn.text = "Buy (%d)" % price
		buy_btn.disabled = bought or RunManager.gold < price
		buy_btn.pressed.connect(_on_buy_merchant_card.bind(i))
		col.add_child(buy_btn)

	var relic_header: Label = Label.new()
	relic_header.text = "Relics"
	relic_header.add_theme_font_size_override("font_size", 18)
	popup_body.add_child(relic_header)

	for i in range(merchant_relic_offers.size()):
		var offer: Dictionary = merchant_relic_offers[i]
		var relic: RelicData = offer.get("relic") as RelicData
		var price: int = int(offer.get("price", 0))
		var bought: bool = bool(offer.get("bought", false))
		if relic == null:
			continue

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		popup_body.add_child(row)

		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(34.0, 34.0)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = relic.icon if relic.icon != null else RELIC_FALLBACK_ICON
		icon.tooltip_text = "%s\n%s" % [relic.get_display_name(), relic.description]
		row.add_child(icon)

		var title: Label = Label.new()
		title.text = "%s (%d gold)" % [relic.get_display_name(), price]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.tooltip_text = "%s\n%s" % [relic.get_display_name(), relic.description]
		row.add_child(title)

		var buy_btn: Button = Button.new()
		buy_btn.text = "Buy"
		buy_btn.disabled = bought or RunManager.gold < price
		buy_btn.pressed.connect(_on_buy_merchant_relic.bind(i))
		row.add_child(buy_btn)

	var purge_header: Label = Label.new()
	purge_header.text = "Remove Card From Deck"
	purge_header.add_theme_font_size_override("font_size", 18)
	popup_body.add_child(purge_header)

	var purge_hint: Label = Label.new()
	purge_hint.text = "Cost: %d (base 50, +25 each time). Minimum deck size is 1." % purge_price
	popup_body.add_child(purge_hint)

	var purge_grid: HFlowContainer = HFlowContainer.new()
	purge_grid.add_theme_constant_override("h_separation", 12)
	purge_grid.add_theme_constant_override("v_separation", 10)
	popup_body.add_child(purge_grid)

	for i in range(RunManager.deck.size()):
		var deck_card: CardData = RunManager.deck[i]
		if deck_card == null:
			continue

		var purge_col: VBoxContainer = VBoxContainer.new()
		purge_col.custom_minimum_size = Vector2(146.0, 260.0)
		purge_grid.add_child(purge_col)

		var purge_card_view: CardView = card_view_scene.instantiate() as CardView
		if purge_card_view != null:
			purge_card_view.use_physics = false
			purge_card_view.custom_minimum_size = Vector2(140.0, 190.0)
			purge_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			purge_card_view.setup(deck_card)
			purge_col.add_child(purge_card_view)

		var purge_btn: Button = Button.new()
		purge_btn.text = "Remove (%d)" % purge_price
		purge_btn.disabled = RunManager.deck.size() <= 1 or RunManager.gold < purge_price
		purge_btn.pressed.connect(_on_purge_merchant_card.bind(i))
		purge_col.add_child(purge_btn)


func _on_buy_merchant_card(index: int) -> void:
	if index < 0 or index >= merchant_card_offers.size():
		return
	var offer: Dictionary = merchant_card_offers[index]
	if bool(offer.get("bought", false)):
		return
	var price: int = int(offer.get("price", 0))
	if RunManager.gold < price:
		return
	var card: CardData = offer.get("card") as CardData
	if card == null:
		return

	RunManager.gold -= price
	var copy: CardData = card.duplicate(true) as CardData
	if copy == null:
		copy = card
	RunManager.deck.append(copy)
	offer["bought"] = true
	merchant_card_offers[index] = offer
	_update_hud()
	_open_merchant_popup()


func _on_buy_merchant_relic(index: int) -> void:
	if index < 0 or index >= merchant_relic_offers.size():
		return
	var offer: Dictionary = merchant_relic_offers[index]
	if bool(offer.get("bought", false)):
		return
	var price: int = int(offer.get("price", 0))
	if RunManager.gold < price:
		return
	var relic: RelicData = offer.get("relic") as RelicData
	if relic == null:
		return
	if relic.id != "" and RunManager.has_relic_id(relic.id):
		offer["bought"] = true
		merchant_relic_offers[index] = offer
		_open_merchant_popup()
		return

	RunManager.gold -= price
	RunManager.add_relic(relic)
	offer["bought"] = true
	merchant_relic_offers[index] = offer
	_update_hud()
	_open_merchant_popup()


func _on_purge_merchant_card(deck_index: int) -> void:
	if deck_index < 0 or deck_index >= RunManager.deck.size():
		return
	if RunManager.deck.size() <= 1:
		return

	var price: int = RunManager.get_merchant_purge_price(
		rest_config.merchant_purge_price_base,
		rest_config.merchant_purge_price_increment
	)
	if RunManager.gold < price:
		return

	RunManager.gold -= price
	RunManager.deck.remove_at(deck_index)
	RunManager.consume_merchant_purge()
	_update_hud()
	_open_merchant_popup()


func _open_smith_popup() -> void:
	popup_mode = "smith"
	_show_popup_shell("Smith")

	var smith_discount_pct: float = RunManager.get_smith_discount_percent() * 100.0
	var free_left: int = RunManager.get_remaining_smith_free_upgrades()
	var gold_info: Label = Label.new()
	gold_info.text = "Gold: %d   |   Smith discount: %.0f%%   |   Free upgrades left: %d" % [
		int(RunManager.gold),
		smith_discount_pct,
		free_left,
	]
	popup_body.add_child(gold_info)

	var cards_row: HFlowContainer = HFlowContainer.new()
	cards_row.add_theme_constant_override("h_separation", 14)
	cards_row.add_theme_constant_override("v_separation", 12)
	popup_body.add_child(cards_row)

	var upgradable_count: int = 0
	for i in range(RunManager.deck.size()):
		var card: CardData = RunManager.deck[i]
		if card == null or card.is_upgraded():
			continue
		upgradable_count += 1

		var col: VBoxContainer = VBoxContainer.new()
		col.custom_minimum_size = Vector2(146.0, 260.0)
		cards_row.add_child(col)

		var card_view: CardView = card_view_scene.instantiate() as CardView
		if card_view != null:
			card_view.use_physics = false
			card_view.custom_minimum_size = Vector2(140.0, 190.0)
			card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_view.setup(card)
			col.add_child(card_view)

		var current_price: int = RunManager.get_smith_upgrade_price_preview(rest_config.smith_upgrade_price)
		var upgrade_btn: Button = Button.new()
		upgrade_btn.text = "Upgrade (%d)" % current_price
		upgrade_btn.disabled = RunManager.gold < current_price
		upgrade_btn.pressed.connect(_on_upgrade_card.bind(i))
		col.add_child(upgrade_btn)

	if upgradable_count == 0:
		var empty_label: Label = Label.new()
		empty_label.text = "All cards in deck are already upgraded."
		popup_body.add_child(empty_label)


func _on_upgrade_card(deck_index: int) -> void:
	if deck_index < 0 or deck_index >= RunManager.deck.size():
		return
	var card: CardData = RunManager.deck[deck_index]
	if card == null or card.is_upgraded():
		return

	var price: int = RunManager.consume_smith_upgrade(rest_config.smith_upgrade_price)
	if RunManager.gold < price:
		if price == 0:
			RunManager.used_smith_free_upgrades = max(0, RunManager.used_smith_free_upgrades - 1)
		return

	RunManager.gold -= price
	card.set_upgraded(true)
	_update_hud()
	_open_smith_popup()


func _show_popup_notice(message: String) -> void:
	popup_mode = "notice"
	_show_popup_shell("Rest Room")
	var label: Label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_body.add_child(label)


func _show_popup_shell(title: String) -> void:
	if popup_overlay == null or popup_body == null or popup_title == null:
		return
	popup_overlay.visible = true
	popup_title.text = title
	for child in popup_body.get_children():
		child.queue_free()


func _close_popup() -> void:
	if popup_overlay != null:
		popup_overlay.visible = false
	popup_mode = ""


func _setup_popup_ui() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud == null:
		return

	popup_overlay = Control.new()
	popup_overlay.name = "RestPopup"
	popup_overlay.visible = false
	popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(popup_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	popup_overlay.add_child(dim)

	popup_panel = PanelContainer.new()
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.offset_left = -390.0
	popup_panel.offset_top = -245.0
	popup_panel.offset_right = 390.0
	popup_panel.offset_bottom = 245.0
	popup_panel.add_theme_stylebox_override("panel", _make_popup_style())
	popup_overlay.add_child(popup_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	popup_panel.add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	popup_title = Label.new()
	popup_title.add_theme_font_size_override("font_size", 24)
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(popup_title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	popup_body = VBoxContainer.new()
	popup_body.add_theme_constant_override("separation", 8)
	popup_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(popup_body)

	popup_close_btn = Button.new()
	popup_close_btn.text = "Close"
	popup_close_btn.pressed.connect(_close_popup)
	root_vbox.add_child(popup_close_btn)


func _make_popup_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.94)
	style.border_color = Color(0.22, 0.25, 0.31, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	return style


func _setup_day_label() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud == null:
		return
	day_label = Label.new()
	day_label.name = "DayLabel"
	day_label.offset_left = 450.0
	day_label.offset_top = 0.0
	day_label.offset_right = 700.0
	day_label.offset_bottom = 23.0
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(day_label)


func _setup_save_exit_button() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud == null:
		return
	save_exit_btn = Button.new()
	save_exit_btn.name = "SaveExitButton"
	save_exit_btn.offset_left = 1048.0
	save_exit_btn.offset_top = 6.0
	save_exit_btn.offset_right = 1272.0
	save_exit_btn.offset_bottom = 34.0
	save_exit_btn.text = "Save & Main Menu"
	save_exit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	save_exit_btn.pressed.connect(_on_save_exit_pressed)
	hud.add_child(save_exit_btn)


func _on_save_exit_pressed() -> void:
	SaveSystem.save_run()
	get_tree().change_scene_to_file("res://menu.tscn")


func _setup_interact_label() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud == null:
		return
	interact_label = Label.new()
	interact_label.name = "InteractLabel"
	interact_label.visible = false
	interact_label.offset_left = 420.0
	interact_label.offset_top = 32.0
	interact_label.offset_right = 930.0
	interact_label.offset_bottom = 64.0
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(interact_label)


func _update_hud() -> void:
	if hp_label != null:
		hp_label.text = "HP: %d/%d" % [int(RunManager.current_hp), int(RunManager.max_hp)]
	if gold_label != null:
		gold_label.text = "Gold: %d" % int(RunManager.gold)
	if floor_label != null:
		floor_label.text = "Floor: %d" % int(RunManager.current_floor)
	if day_label != null:
		day_label.text = "Time: %s" % _time_of_day_text()
	_refresh_relic_panel()


func _time_of_day_text() -> String:
	return "Night" if RunManager.is_night else "Day"


func _setup_relic_panel() -> void:
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud == null:
		return
	relic_panel = PanelContainer.new()
	relic_panel.name = "RelicPanel"
	relic_panel.anchor_left = 1.0
	relic_panel.anchor_top = 0.0
	relic_panel.anchor_right = 1.0
	relic_panel.anchor_bottom = 0.0
	relic_panel.offset_left = -330.0
	relic_panel.offset_top = 8.0
	relic_panel.offset_right = -8.0
	relic_panel.offset_bottom = 56.0
	relic_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	hud.add_child(relic_panel)

	relic_icons_row = HBoxContainer.new()
	relic_icons_row.alignment = BoxContainer.ALIGNMENT_END
	relic_icons_row.mouse_filter = Control.MOUSE_FILTER_PASS
	relic_panel.add_child(relic_icons_row)

	relic_tooltip = PanelContainer.new()
	relic_tooltip.name = "RelicTooltip"
	relic_tooltip.visible = false
	relic_tooltip.custom_minimum_size = Vector2(280.0, 95.0)
	relic_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_tooltip.z_index = 20
	relic_tooltip.add_theme_stylebox_override("panel", _make_popup_style())
	hud.add_child(relic_tooltip)

	var tooltip_vbox: VBoxContainer = VBoxContainer.new()
	relic_tooltip.add_child(tooltip_vbox)

	relic_tooltip_title = Label.new()
	relic_tooltip_title.add_theme_font_size_override("font_size", 16)
	tooltip_vbox.add_child(relic_tooltip_title)

	relic_tooltip_desc = Label.new()
	relic_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_vbox.add_child(relic_tooltip_desc)
	_refresh_relic_panel()


func _refresh_relic_panel() -> void:
	if relic_icons_row == null:
		return
	var new_signature: String = _build_relic_signature()
	if new_signature == relic_signature_cached:
		return
	relic_signature_cached = new_signature

	for child in relic_icons_row.get_children():
		child.queue_free()

	for relic in RunManager.relics:
		if relic == null:
			continue
		if not relic.is_active_for_time(RunManager.is_night):
			continue
		var icon_holder: TextureRect = TextureRect.new()
		icon_holder.custom_minimum_size = Vector2(34.0, 34.0)
		icon_holder.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_holder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_holder.mouse_filter = Control.MOUSE_FILTER_STOP
		icon_holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		icon_holder.texture = relic.icon if relic.icon != null else RELIC_FALLBACK_ICON
		icon_holder.mouse_entered.connect(_on_relic_icon_mouse_entered.bind(icon_holder, relic))
		icon_holder.mouse_exited.connect(_on_relic_icon_mouse_exited)
		relic_icons_row.add_child(icon_holder)

	if relic_tooltip != null:
		relic_tooltip.visible = false


func _build_relic_signature() -> String:
	if RunManager.relics.is_empty():
		return "-"
	var parts: PackedStringArray = []
	for relic in RunManager.relics:
		if relic == null:
			continue
		if not relic.is_active_for_time(RunManager.is_night):
			continue
		parts.append(relic.id + "|" + relic.get_display_name())
	return "||".join(parts)


func _on_relic_icon_mouse_entered(icon: TextureRect, relic: RelicData) -> void:
	if relic_tooltip == null or relic_tooltip_title == null or relic_tooltip_desc == null:
		return
	relic_tooltip_title.text = relic.get_display_name()
	relic_tooltip_desc.text = relic.description
	var size_hint: Vector2 = relic_tooltip.get_combined_minimum_size()
	relic_tooltip.global_position = icon.global_position + Vector2(-size_hint.x - 10.0, 8.0)
	relic_tooltip.visible = true


func _on_relic_icon_mouse_exited() -> void:
	if relic_tooltip != null:
		relic_tooltip.visible = false
