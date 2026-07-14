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
- Minimum and maximum pack size.
- Pack spread and whether enemy types may mix inside a pack.
- Context tags and monster modifier sets.

## Current enemy archetypes

- Chasing enemy: moves directly toward the player and applies contact pressure.
- Wandering enemy: moves around the player perimeter and creates ambient pressure.
- Ranged enemy: tries to enter a preferred ring around the player, stops while charging, then fires a projectile.

The ranged enemy uses a min/max attack ring. Current authored tuning keeps it around `260-420` units from the player. Once inside that ring, it stops moving for a `1.5s` charge before firing. If the player moves and the enemy leaves the ring, it repositions before charging again.

Ranged enemies begin appearing from Wave 2 through `ranged_enemy_entry.tres` and are included in Wave 2 and Wave 3 enemy pools.

Spawns are planned at wave start. The spawn director spends the wave budget on eligible base enemy entries, natural monster rarity, entry weight, and entry cost. It chunks the planned composition into packs, then distributes those packs across spawn windows.

## Monster rarities

Monster rarity has two steps. First, the spawn director rolls the monster's natural rarity and spends the wave budget using that rarity's cost multiplier. Second, player Monster Rarity can upgrade the already-planned monster after budget is spent.

Current monster rarities:

- Normal: `1x` spawn cost, no extra modifiers, and `1.0x` reward multiplier.
- Uncommon: `3x` spawn cost, can start on Wave 3, has increased health, armour, evasion, resistances, and `1.35x` reward multiplier.
- Rare: `5x` spawn cost, can start on Wave 6, has larger armour/evasion bonuses, increased health, `2.0x` reward multiplier, and can roll rare monster modifiers.

Current rarity chance formulas:

```text
natural_uncommon_chance = clamp((wave - 2) x 4%, 0%, 25%)
natural_rare_chance = clamp((wave - 5) x 2%, 0%, 12%)
effective_monster_rarity_multiplier = clamp(monster_rarity_multiplier, 0, 3)
```

Natural Rare rolls before natural Uncommon and spends `5x` budget if selected. If the natural rarity cannot fit in the remaining budget, it downgrades until it can fit. Player Monster Rarity then runs a second-pass weighted upgrade roll without changing the already-spent budget. At `1.0x`, no upgrade weights are added, so the natural spawn composition is preserved. Above `1.0x`, upgrade weights use the same soft-capped style as item rarity:

```text
stay_current_rarity_weight = 70
upgrade_uncommon_weight = 22 x (effective_monster_rarity_multiplier - 1) x relative_rarity_index
upgrade_rare_weight = 6 x (effective_monster_rarity_multiplier - 1) x relative_rarity_index
```

For a natural Normal monster at `2.0x` Monster Rarity, the second pass rolls between `70` stay-Normal weight, `22` upgrade-to-Uncommon weight, and `12` upgrade-to-Rare weight. Rare monster modifiers are self-only in the current implementation. Aura-style rare modifiers are future work.

By default, the last 5 seconds before the main timer expires are reserved for cleanup. No new planned packs are scheduled during that final period, giving the player time to kill remaining enemies.

The timer controls enemy spawning, not immediate wave completion. When the timer expires, spawning stops and the wave enters a cleanup phase. The wave ends only after all required active enemies are defeated.

Timed-out enemy cleanup is batched and uses the enemy pool instead of deleting every active enemy in one frame. This reduces spikes at the end of waves while preserving active-enemy count updates.

Post-wave resolution happens in this order:

- Auto-collect remaining drops.
- Item evaluation for dropped items and Relics.
- Queued level-up choices.
- Shop.
- Content choice for the next wave.

This prevents the shop phase from racing ahead of delayed experience collection, dropped-item decisions, or pending level-up UI.

Drop cleanup gathers collectable drops once, batches very large piles directly, and waits only on the touched animated pickups. This avoids repeated full drop-container scans during end-wave cleanup.

Enemy packs are announced with spawn indicators, then appear outside the camera view and at a minimum distance from the player.

Each prepared wave also applies monster base health scaling. By default, monster base maximum health is multiplied by `+10%` per wave after Wave 1. This means a 90-base-health enemy has 90 base health on Wave 1, 99 on Wave 2, 108 on Wave 3, and so on before Content-specific modifiers are stacked.

Waves also apply natural monster defensive scaling:

```text
natural_armour = floor(wave / 5) x 25
natural_evasion = floor(wave / 5) x 25
natural_physical_resistance = floor(wave / 10) x 10
natural_elemental_resistance = floor(wave / 10) x 10
```

This means Wave 5 starts giving normal monsters `+25` Armour and Evasion, Wave 10 adds `+10` Physical and Elemental resistance, and Wave 40 reaches `+200` Armour/Evasion and `+40` resistance before rarity or Content modifiers.

Monster rarity adds additional baseline defenses:

```text
Uncommon: +50 Armour, +50 Evasion, +15 Physical Resistance, +15 Elemental Resistance
Rare: +100 Armour, +100 Evasion, +15 Physical Resistance, +15 Elemental Resistance
```

Toughness is not part of natural wave or rarity scaling. It remains an optional Content, modifier, or player-chosen juicing lever.

The current game contains three configured wave resources and repeats the last definition by default. Repeated waves increase spawn budget by `+10` per wave after the last authored wave. With the current authored budgets, the curve is:

```text
Wave 1: 16
Wave 2: 30
Wave 3: 45
Wave 4: 55
Wave 5: 65
Wave 6: 75
```

This keeps late-wave monster volume and reward opportunity growing even while authored wave resources are still limited.

## Related systems

- [[Core Gameplay]]
- [[Active Skills]]
- [[Stats and Modifiers]]
- [[Boss Encounter]]
- [[Hellforge Gauntlet]]
