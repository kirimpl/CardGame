# Demo Mode (For Defense)

## Goal
Produce a stable, repeatable showcase for commission/demo playback.

## Setup
- Set fixed run seed in `RunManager.fixed_seed`.
- Start new run.
- Optional: use Debug panel for floor/time/mutator pre-setup.

## Recommended Demo Script
1. Show main menu and compendium unlock filtering.
2. Enter map and choose different node types.
3. Run one normal combat:
   - show intent payload,
   - show damage breakdown,
   - show effect tooltips.
4. Visit rest room:
   - smith upgrade,
   - merchant reroll/pin/purge.
5. End run and show result screen (XP, progression).
6. Export logs:
   - `combat_log_last.txt`
   - `replay_last.json`
   - `sim_report.csv`.

## Artifacts to Attach
- `Docs/ARCHITECTURE.md`
- `Docs/BALANCE_METHOD.md`
- latest `sim_report.csv`
- one replay export and one combat log export.
