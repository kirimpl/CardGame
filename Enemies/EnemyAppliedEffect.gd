extends Resource
class_name EnemyAppliedEffect

@export var effect: EffectData
@export var duration: int = 1
@export var stacks: int = 1
@export_range(0, 100, 1) var chance_percent: int = 100
