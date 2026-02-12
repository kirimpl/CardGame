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

enum TickWhen { END_TURN, START_TURN }
@export var tick_when: TickWhen = TickWhen.END_TURN
