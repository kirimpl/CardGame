# Balance Method

## Target Ranges (Act 1, floors 1-10)
- Normal winrate: `~65-80%` (starter baseline).
- Elite winrate: `~40-60%` (noticeably harder).
- Mixed winrate trend: high early, gradual decline by floor 10.
- Avg turns: should rise with floor.
- Avg HP left: should decrease with floor.

## Tuning Inputs
- Economy:
  - `Rest/Data/DefaultRestConfig.tres`
  - merchant prices, purge/reroll costs, smith cost.
- Global combat scaling:
  - `Config/Data/DefaultBalanceConfig.tres`
  - day/night multipliers, mutator weights, shard economy.
- Enemy scaling:
  - enemy base HP/damage, elite multipliers, intent/action pools.
- Player scaling:
  - card baseline values and upgraded values.
  - relic effects and rarity rates.

## Process
1. Run 100-fight simulation for current floor.
2. Export floor 1-10 CSV.
3. Compare against target ranges.
4. Apply one focused pass:
  - either economy, or enemy scaling, or card/relic value.
5. Re-run sim and verify trend, not only one floor.

## Anti-RNG Frustration
- Reward card picker uses archetype bias.
- Duplicate pressure is reduced (weighted down) in reward generation.
- Merchant supports reroll and pin to retain strategic choices.

## Validation Checklist
- No parse/runtime errors.
- No impossible shops (purge/reroll availability and prices visible).
- Intent payload readable (`Debuff: X xN, chance`).
- Damage preview includes breakdown contributions.
