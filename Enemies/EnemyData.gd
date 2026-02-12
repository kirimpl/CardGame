extends Resource
class_name EnemyData

@export_group("Внешний вид")
@export var name: String = "Enemy"
@export var sprite_frames: SpriteFrames 
@export var scale: float = 1.0 


@export var overworld_offset: Vector2 = Vector2(0, 0) 
@export var battle_offset: Vector2 = Vector2(0, 0)  
@export var flip_h: bool = false         

@export_group("Характеристики Боя")
enum Difficulty { NORMAL, ELITE, BOSS }
@export var difficulty: Difficulty = Difficulty.NORMAL
@export var base_hp: int = 20
@export var base_damage: int = 5

@export_group("Награды")
@export var min_gold: int = 10
@export var max_gold: int = 25 

@export_group("ИИ")
enum Intent { ATTACK, DEFEND, BUFF }
@export var battle_actions: Array[Intent] = [Intent.ATTACK]
