extends Resource
class_name RelicData

enum RelicRarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export_group("Identity")
@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var rarity: RelicRarity = RelicRarity.COMMON

@export_group("Survivability")
@export var max_hp_bonus: int = 0
@export var heal_on_pickup_flat: int = 0
@export_range(0.0, 1.0, 0.01) var heal_on_pickup_percent: float = 0.0
@export var one_time_revive: bool = false
@export_range(0.01, 1.0, 0.01) var revive_hp_percent: float = 0.3

@export_group("Card Buff Filters")
@export var card_id_filters: PackedStringArray = PackedStringArray()
@export var use_card_type_filter: bool = false
@export var card_type_filter: CardData.CardType = CardData.CardType.ATTACK
@export var require_upgraded_card: bool = false

@export_group("Card Buff Values")
@export var attack_damage_bonus: int = 0
@export var defense_bonus: int = 0
@export var cost_delta: int = 0
@export var effect_durability_bonus: int = 0
@export var buff_charges_bonus: int = 0

func get_display_name() -> String:
	return title if title != "" else id

func has_card_stat_modifiers() -> bool:
	return attack_damage_bonus != 0 \
		or defense_bonus != 0 \
		or cost_delta != 0 \
		or effect_durability_bonus != 0 \
		or buff_charges_bonus != 0
