# Stats and Modifiers

> [!info] Status
> Implemented foundation.

Actors and weapons resolve values through reusable stat profiles and components. Modifiers can be filtered by stat, tags, target domain, and local or global scope.

## Modifier operations

- **Flat:** adds a fixed value.
- **Increased:** combines additively with other increased modifiers.
- **More:** multiplies separately with other more modifiers.

## Current applications

- Player and monster health and movement.
- Weapon damage, attack rate, range, and projectile speed.
- Typed damage, conversion, resistance, and maximum resistance.
- Toughness.
- Monster Effectiveness.
- Experience granted and player experience-gain multipliers.
- Item quantity and item rarity multipliers.
- Relic chance multipliers.
- Shop offer count, reroll cost, and free reroll chance.
- Gold granted and gold gain multipliers. Monster reward sources use gold granted; player-owned modifiers use gold gain.
- Monster rarity multiplier.
- Pickup range.
- Instant pickup chance, clamped between 0% and 100%.

Reward multipliers default to `1.0`. Experience Granted, Item Quantity, Item Rarity, and Gold Granted belong naturally to monsters or encounter reward sources. Experience Gain and Gold Gain belong to the player. Monster Rarity is available to influence enemy rarity selection once monster rarity bands are implemented.

Relic chance currently affects shop Relic appearance:

- Relic Chance Multiplier applies globally to Relic appearance.
- Shop Relic Chance Multiplier applies to Relics appearing in the shop.

Shop Relic chance currently uses `base shop Relic chance x Relic Chance Multiplier x Shop Relic Chance Multiplier`.

Monster drops no longer use a separate Relic chance. Relics roll through the same item-drop path as normal items.

Shop economy uses three player-facing stats:

- Shop Extra Offer Count uses flat value to add shop item slots. A value of `+1` raises the default shop from 3 offers to 4.
- Shop Reroll Cost Multiplier defaults to `1.0` and supports increased and more modifiers. Negative values reduce or lessen reroll cost.
- Shop Free Reroll Chance is a percentage chance to make a reroll free and supports flat, increased, and more modifiers.

Shop item rarity currently uses `Item Rarity Multiplier x Shop Item Rarity Multiplier`.

Wave definitions and the runtime modifier registry can attach modifier sets to tagged monsters. Runtime sources can update existing monsters as well as future spawns. This is the current technical foundation for content-specific effects such as [[Rift]] modifiers and Hell Pacts in the [[Hellforge Gauntlet]].

Spawned enemies copy their spawn context tags into their `StatComponent` as default context tags. This lets tag-gated monster modifiers apply even when health, rewards, or melee damage ask for a stat without explicitly passing tags.

Monster Effectiveness currently:

- Improves effective toughness by 1% per point.
- Improves experience and item-quantity multipliers by 0.5% per point.

## Monster reward formulas

Reward math is centralized in `MonsterRewardComponent`. The tunable base values are 5 experience and 2 gold per spawn-budget cost.

```text
Experience = XP per cost × spawn cost × XP granted × Effectiveness reward × rarity reward × player XP gain × triangular random factor (±10%)
Gold = gold per cost × spawn cost × monster gold granted × Effectiveness reward × rarity reward × player gold gain × triangular random factor (±20%)
```

The Effectiveness reward multiplier is `1 + Monster Effectiveness / 200`.

Total expected monster reward per wave scales primarily with the prepared wave's spawn budget. The current repeated-wave budget scaling adds `+10` spawn budget per wave after the last authored wave, so base reward opportunity continues to grow linearly instead of flattening after wave 3.

Monster item drop rolls are also centralized in `MonsterRewardComponent`. Rolled item and Relic drops spawn visible world pickups, then collect into post-wave item evaluation.

Current item-drop defaults:

- Combined item/Relic drop chance: 2% per monster spawn cost.
- Maximum item drops from one monster: 3.

```text
Item/Relic expected drops = spawn cost x 2% x monster item quantity x player item quantity
Item rarity roll = monster item rarity x player item rarity x rarity reward multiplier
```

The monster drop pool currently falls back to the shop item pool if no dedicated monster drop pool is assigned. Relics and normal items share this pool for monster drops.
