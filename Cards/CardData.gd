extends Resource
class_name CardData

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var cost: int = 1

@export var damage: int = 0
@export var defense: int = 0
@export var exhaust: bool = false

@export_group("Effects")
@export var effect: EffectData
@export var effect_durability: int = 0

enum CardType { ATTACK, DEFENSE, BUFF }
enum BuffKind { NONE, ENCHANT_ATTACK_EFFECT, APPLY_SELF_EFFECT }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export_group("Meta")
@export var rarity: Rarity = Rarity.COMMON
@export var can_appear_in_rewards: bool = true
@export var can_appear_in_merchant: bool = true

@export_group("Buff")
@export var buff_kind: BuffKind = BuffKind.NONE
@export var buff_charges: int = 0
@export var buff_effect: EffectData
@export var buff_effect_durability: int = 0

@export_group("Targeting")
@export var hits_all_enemies: bool = false

@export_group("Upgrade Constructor")
@export var upgraded: bool = false
@export_multiline var upgraded_description: String = ""
@export var upgraded_cost: int = -1
@export var upgraded_damage: int = -1
@export var upgraded_defense: int = -1
@export var upgraded_effect_durability: int = -1
@export var upgraded_buff_charges: int = -1
@export var upgraded_buff_effect_durability: int = -1
@export var use_upgraded_exhaust_override: bool = false
@export var upgraded_exhaust: bool = false
@export var auto_upgrade_tuning: bool = true


func set_upgraded(value: bool) -> void:
	upgraded = value


func is_upgraded() -> bool:
	return upgraded


func get_display_title() -> String:
	if upgraded:
		return title + "+"
	return title


func get_description() -> String:
	if upgraded and upgraded_description != "":
		return upgraded_description
	return description


func _auto_upgrade_cost_bonus(base_cost: int) -> int:
	if base_cost >= 2:
		return -1
	return 0


func get_cost() -> int:
	var base_cost: int = max(0, cost)
	if not upgraded:
		return base_cost
	if upgraded_cost >= 0:
		return max(0, upgraded_cost)
	if auto_upgrade_tuning:
		return max(0, base_cost + _auto_upgrade_cost_bonus(base_cost))
	return base_cost


func get_damage() -> int:
	var base_damage: int = max(0, damage)
	if not upgraded:
		return base_damage
	if upgraded_damage >= 0:
		return max(0, upgraded_damage)
	if auto_upgrade_tuning and base_damage > 0:
		return base_damage + 3
	return base_damage


func get_defense() -> int:
	var base_defense: int = max(0, defense)
	if not upgraded:
		return base_defense
	if upgraded_defense >= 0:
		return max(0, upgraded_defense)
	if auto_upgrade_tuning and base_defense > 0:
		return base_defense + 3
	return base_defense


func get_exhaust() -> bool:
	if upgraded and use_upgraded_exhaust_override:
		return upgraded_exhaust
	return exhaust

func has_effect() -> bool:
	return effect != null and effect.id != ""

func get_effect_id() -> String:
	var eff: EffectData = get_effect()
	return eff.id if eff else ""


func get_effect() -> EffectData:
	return effect

func get_effect_value() -> int:
	var eff: EffectData = get_effect()
	return eff.value if eff else 0

func get_effect_durability() -> int:
	var eff: EffectData = get_effect()
	if eff == null:
		return 0
	var base_durability: int = effect_durability if effect_durability > 0 else int(eff.default_durability)
	if not upgraded:
		return base_durability
	if upgraded_effect_durability >= 0:
		return upgraded_effect_durability
	if auto_upgrade_tuning:
		return base_durability + 1
	return base_durability


func get_buff_charges() -> int:
	var base_charges: int = max(0, buff_charges)
	if not upgraded:
		return base_charges
	if upgraded_buff_charges >= 0:
		return max(0, upgraded_buff_charges)
	if auto_upgrade_tuning and base_charges > 0:
		return base_charges + 1
	return base_charges


func get_buff_effect() -> EffectData:
	return buff_effect

func get_card_type() -> CardType:
	if get_damage() > 0:
		return CardType.ATTACK
	if get_defense() > 0:
		return CardType.DEFENSE
	if buff_kind != BuffKind.NONE:
		return CardType.BUFF
	if has_effect():
		return CardType.BUFF
	return CardType.ATTACK

func is_attack_with_fire() -> bool:
	if get_damage() <= 0:
		return false
	return has_effect() and get_effect_id() == "burn"

func get_buff_effect_durability() -> int:
	var eff: EffectData = get_buff_effect()
	if eff == null:
		return 0
	var base_durability: int = buff_effect_durability if buff_effect_durability > 0 else int(eff.default_durability)
	if not upgraded:
		return base_durability
	if upgraded_buff_effect_durability >= 0:
		return upgraded_buff_effect_durability
	if auto_upgrade_tuning:
		return base_durability + 1
	return base_durability

func get_rarity_name() -> String:
	match rarity:
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Common"


func get_hits_all_enemies() -> bool:
	return hits_all_enemies
