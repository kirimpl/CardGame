extends Control


@export var spread_curve: Curve
@export var height_curve: Curve


const HAND_WIDTH: float = 800.0
const MAX_ROTATION_DEGREES: float = 15.0
const CARD_Y_OFFSET: float = 30.0 

var cards: Array[CardView] = []
var hovered_card_index: int = -1


func add_card_to_hand(card_view: CardView) -> void:
	add_child(card_view)
	cards.append(card_view)

	card_view.card_hovered.connect(_on_card_hovered)
	card_view.card_unhovered.connect(_on_card_unhovered)

	_update_card_positions()


func remove_card_from_hand(card_view: CardView) -> void:
	if card_view in cards:
		cards.erase(card_view)
		card_view.queue_free()
		_update_card_positions()


func clear_hand() -> void:
	for c in cards:
		c.queue_free()
	cards.clear()


func _update_card_positions() -> void:
	for i in range(cards.size()):
		var card: CardView = cards[i]


		var ratio: float = 0.5
		if cards.size() > 1:
			ratio = float(i) / float(cards.size() - 1)


		var total_width: float = min(float(cards.size()) * 80.0, HAND_WIDTH)
		var final_x: float = (ratio - 0.5) * total_width

	
		var center_offset: float = abs(ratio - 0.5)
		var final_y: float = center_offset * 40.0

		
		var final_rot: float = (ratio - 0.5) * MAX_ROTATION_DEGREES

	
		var height_fix: float = -100.0

	
		if i == hovered_card_index:
			card.target_position = Vector2(final_x, final_y + height_fix - 80.0)
			card.target_rotation = 0.0
			card.target_scale = Vector2(1.2, 1.2)
			card.z_index = 100
		else:
			card.target_position = Vector2(final_x, final_y + height_fix)
			card.target_rotation = final_rot
			card.target_scale = Vector2(1.0, 1.0)
			card.z_index = i

			if hovered_card_index != -1:
				var dist: int = abs(i - hovered_card_index)
				if dist <= 2 and dist > 0:
					var push_dir: float = 1.0 if i > hovered_card_index else -1.0
					card.target_position.x += push_dir * 40.0 / float(dist)


func _on_card_hovered(card: CardView) -> void:
	hovered_card_index = cards.find(card)
	_update_card_positions()


func _on_card_unhovered(card: CardView) -> void:
	if hovered_card_index == cards.find(card):
		hovered_card_index = -1
		_update_card_positions()
