# Wave System

> [!info] Status
> Implemented foundation.

Runs progress through preparation, active spawning, clearing, post-wave resolution, shop, Content choice, and then the next preparation state.

Once [[Active Skills]] are implemented, the period between rounds will be the player's opportunity to change their two equipped skills. Skill loadouts will be locked once the next wave begins.

Each wave definition controls:

- Duration and spawn budget.
- Spawn warning duration.
- Eligible enemies, their costs, weights, and wave requirements.
- Spawn cutoff before wave end and spawn window duration.
- Budget share for Elite enemies.
- Minimum and maximum pack size.
- Pack spread and whether enemy types may mix inside a pack.
- Context tags and monster modifier sets.

Spawns are planned at wave start. The spawn director splits the wave budget into Normal and Elite budget pools using the wave's weighted budget share, chooses enemies for each pool by entry weight and cost, chunks the planned composition into packs, then distributes those packs across spawn windows.

## Elite enemies

Elite enemies use the same enemy spawning pipeline as normal enemies, but they are authored as `EnemySpawnEntry` resources with `spawn_role = ELITE`. Each wave can reserve part of its spawn budget for elites through `elite_budget_share`.

The first implemented elite is **Elite Chasing Enemy**:

- Starts appearing on wave 3.
- Uses the Elite budget pool.
- Costs 8 spawn budget.
- Is larger and purple-tinted for readability.
- Has higher health, melee damage, toughness, and monster effectiveness than the normal Chasing Enemy.

Wave 3 currently uses `elite_budget_share = 0.15`, which gives it about 8 elite budget from its 54 total budget and therefore usually plans one Elite Chasing Enemy. Repeated waves inherit this wave and scale total budget upward, so elite budget also grows over time.

By default, the last 5 seconds before the main timer expires are reserved for cleanup. No new planned packs are scheduled during that final period, giving the player time to kill remaining enemies.

The timer controls enemy spawning, not immediate wave completion. When the timer expires, spawning stops and the wave enters a cleanup phase. The wave ends only after all required active enemies are defeated.

Post-wave resolution happens in this order:

- Auto-collect remaining drops.
- Item evaluation for dropped items and Relics.
- Queued level-up choices.
- Shop.
- Content choice for the next wave.

This prevents the shop phase from racing ahead of delayed experience collection, dropped-item decisions, or pending level-up UI.

Enemy packs are announced with spawn indicators, then appear outside the camera view and at a minimum distance from the player.

The current game contains three configured wave resources and repeats the last definition by default. Repeated waves increase spawn budget by `+10` per wave after the last authored wave. With the current authored budgets, the curve is:

```text
Wave 1: 20
Wave 2: 36
Wave 3: 54
Wave 4: 64
Wave 5: 74
Wave 6: 84
```

This keeps late-wave monster volume and reward opportunity growing even while authored wave resources are still limited.

## Related systems

- [[Core Gameplay]]
- [[Active Skills]]
- [[Stats and Modifiers]]
- [[Boss Encounter]]
- [[Hellforge Gauntlet]]
