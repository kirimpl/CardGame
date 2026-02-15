extends Resource
class_name EnemyData
const EnemyAppliedEffectRes = preload("res://Enemies/EnemyAppliedEffect.gd")

@export_group("Visual")
@export var name: String = "Enemy"
@export var sprite_frames: SpriteFrames
@export var scale: float = 1.0
@export var overworld_offset: Vector2 = Vector2.ZERO
@export var battle_offset: Vector2 = Vector2.ZERO
@export var flip_h: bool = false

@export_group("Combat Stats")
enum Difficulty { NORMAL, ELITE, BOSS }
@export var difficulty: Difficulty = Difficulty.NORMAL
@export var base_hp: int = 20
@export var base_damage: int = 5

@export_group("Rewards")
@export var min_gold: int = 10
@export var max_gold: int = 25

@export_group("AI")
enum Intent { ATTACK, DEFEND, BUFF, DEBUFF }
@export var battle_actions: Array[Intent] = [Intent.ATTACK]

@export_group("Effect Control")
@export var defend_effects_on_self: Array[EnemyAppliedEffectRes] = []
@export var buff_effects_on_self: Array[EnemyAppliedEffectRes] = []
@export var debuff_effects_on_player: Array[EnemyAppliedEffectRes] = []
