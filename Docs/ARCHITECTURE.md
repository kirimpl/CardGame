# Architecture and Data Flow

## Runtime Layers
- `Autoload/RunManager.gd`: single source of run state (HP, gold, deck, relics, floor, mutators, map, logs).
- `Autoload/SaveSystem.gd`: save/load, schema migration, CSV/sim exports.
- `Autoload/MetaProgression.gd`: profile XP, unlocks, compendium visibility.
- `battle_manager.gd`: combat orchestration and UI sync.
- `enemy_battle.gd`: enemy runtime behavior and intent resolution.
- `level.gd`: overworld room loop (combat entry, rest/smith/merchant, events).

## Combat Separation (current)
- `Combat/EffectKeys.gd`: canonical IDs for statuses/effects.
- `Combat/StatusSystem.gd`: shared apply/format rules for effect stacks.
- `battle_manager.gd` and `enemy_battle.gd` both call `StatusSystem` to avoid player/enemy divergence.

## Content Data
- Cards: `Cards/Data/**.tres` (`CardData.gd` resource model).
- Relics: `Relic/Data/**.tres` (`RelicData.gd` resource model).
- Enemies by act: `Enemies/Act*/**.tres` (`EnemyData.gd` resource model).
- Balance config: `Config/Data/DefaultBalanceConfig.tres`.
- Rest economy config: `Rest/Data/DefaultRestConfig.tres`.

## Save Schema
- `SaveSystem.SAVE_VERSION = 2`.
- Root payload fields:
  - `schema_version`, `saved_at_unix`, `scene_path`, `run_state`, `meta_state`.
- `run_state` includes:
  - deck/relic serialization, map graph, mutators, combat log/events, replay events, merchant counters.
- Migrations are applied in `_migrate_payload(...)` before import.

## Scene Flow
1. `menu.tscn` -> New run / Continue.
2. `level.tscn` room loop (enemy/rest/event/treasure/merchant).
3. `fight.tscn` combat.
4. return to `level.tscn` or map screen.
5. `run_result.tscn` on run end.

## Determinism and Replay-lite
- Run seed is stored in `RunManager`.
- Replay events are appended during gameplay and exported to `user://replay_last.json`.
- Combat event stream exported to `user://combat_log_last.txt`.
