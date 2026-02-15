extends Resource
class_name EffectData

# Ресурс-описание эффекта/статуса.
# Один EffectData можно назначать в разные CardData.

@export var id: String = ""              # уникальный id для логики ("burn", "poison" ...)
@export var title: String = ""           # красивое имя для UI
@export_multiline var description: String = ""

enum EffectType { NONE, BURN, POISON }
@export var type: EffectType = EffectType.NONE

# Базовое значение эффекта.
# Для DOT (Burn/Poison) — урон за тик при 1 стаке.
@export var value: int = 0

# Дефолтная длительность, если карта не переопределяет.
@export var default_durability: int = 0

# Стакуется ли эффект.
@export var stackable: bool = true

# Наносит ли урон на тике. Если да — сила растёт от стаков.
@export var is_damage_over_time: bool = false
@export var is_percent_of_current_hp_dot: bool = false

enum TickWhen { END_TURN, START_TURN }
@export var tick_when: TickWhen = TickWhen.END_TURN

@export var miss_chance_percent: int = 0
@export_range(0.0, 3.0, 0.01) var incoming_damage_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.01) var outgoing_damage_multiplier: float = 1.0
@export var skip_turn_charges: int = 0
