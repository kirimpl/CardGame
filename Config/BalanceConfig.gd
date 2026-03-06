extends Resource
class_name BalanceConfig

@export_group("XP")
@export var xp_floor_mult: int = 8
@export var xp_fight_win: int = 12
@export var xp_effect_applied_mult: float = 0.8
@export var xp_effect_damage_mult: float = 0.15
@export var xp_heal_mult: float = 0.2
@export var xp_victory_bonus: int = 50
@export var xp_defeat_multiplier: float = 0.45
@export var xp_minimum: int = 6

@export_group("Flux")
@export var starting_time_shards: int = 1
@export var max_time_shards: int = 4
@export var shards_per_floor: int = 1
@export var time_toggle_cost: int = 1

@export_group("Phase Multipliers")
@export var night_dot_multiplier: float = 1.15
@export var night_debuff_multiplier: float = 1.10
@export var day_block_multiplier: float = 1.15
@export var day_heal_multiplier: float = 1.15

@export_group("Mutators")
@export var mutator_none_weight: float = 0.40
@export var mutator_bleed_x2_weight: float = 0.18
@export var mutator_heal_half_weight: float = 0.12
@export var mutator_first_skill_free_weight: float = 0.20
@export var mutator_first_attack_bonus_weight: float = 0.10

