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
- Projectile behavior stats: pierce, fork, chain, and chain radius.
- Projectile status delivery stats: slow chance, slow magnitude, and slow duration.
- Skill area and cooldown duration.
- Physical and Elemental typed damage, conversion, resistance, and maximum resistance.
- Accuracy, Physical Resistance Penetration, Elemental Resistance Penetration, and Armour Penetration.
- Toughness, Armour, Evasion, Deflection Damage Reduction, and Arcane Shield.
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

Fire, cold, and lightning are not stat-backed damage types. Elemental damage is the single damage and resistance family for non-physical damage. Future elemental flavor should live in status/effect mechanics instead of separate damage stats.

Projectile behavior stats currently use flat values:

- `projectile_pierce`: extra Pierce count.
- `projectile_fork`: extra Fork count.
- `projectile_chain`: extra Chain count.
- `projectile_chain_radius`: extra Chain search radius.
- `slow_chance`: chance for configured projectile hits to apply Slow.
- `slow_magnitude`: Slow magnitude applied by configured projectile hits.
- `slow_duration`: Slow duration applied by configured projectile hits.

Skill area stats:

- `area_of_effect`: scales area-skill radius. Frost Nova reads this from the selected bound weapon's local modifiers with `active_skill`, `frost_nova`, `elemental`, `aoe`, and `area` tags.
- `cooldown_duration`: scales active skill cooldowns. Negative increased modifiers reduce cooldown duration, while more/less modifiers multiply cooldown duration.

Relics and other item definitions can carry `DamageConversion` resources. Current relic conversions use `GAIN_AS_EXTRA`, which adds destination damage from a frozen source pool without consuming the source damage.

Forked projectiles carry the `forked` tag. The default Fork damage penalty is implemented as a `Damage` stat modifier with `Operation.MORE`, value `-30`, target domain `weapon`, and `required_all_tags = [&"forked"]`.

Slow is implemented through `StatusEffectComponent` rather than as generic generated affixes. It applies a temporary `MORE` movement-speed modifier to monsters and exposes an action-speed multiplier for enemy attack components. Specific weapon bases can grant Slow delivery through local weapon stats.

Slow action breakpoints:

- Below 25%: no action speed reduction.
- 25% or higher: 15% action speed reduction.
- 50% or higher: 30% action speed reduction.

The current action-speed multiplier is read by contact damage and ranged enemy attack components.

Monster Effectiveness currently:

- Adds into Toughness for monster damage mitigation.
- Improves experience and item-quantity multipliers by 0.5% per point.

Defensive rating stats currently use rating-only soft-cap curves:

```text
effective_evasion = max(evasion - attacker_accuracy, 0)
evade_chance = 75% x effective_evasion / (effective_evasion + 500)
effective_armour = max(armour - attacker_armour_penetration, 0)
armour_reduction = 90% x effective_armour / (effective_armour + 800)
```

Larger hits no longer directly reduce Evasion or Armour. Accuracy reduces the defender's Evasion rating before Evasion and Deflection chances are calculated. Armour Penetration reduces the defender's Armour rating before the Armour formula.

Resistance penetration is type-specific and subtracts from the defender's capped effective resistance before damage is multiplied:

```text
effective_resistance = max(min(resistance, maximum_resistance) - penetration, -100%)
```

Natural wave scaling can add flat Armour, Evasion, Physical Resistance, and Elemental Resistance to monsters. Monster rarity can add additional flat Armour/Evasion and resistance. Natural wave and rarity scaling do not add Toughness.

Deflection uses the evasion chance as a second roll when evasion fails. On success, it reduces the hit by Deflection Damage Reduction, which defaults to 20%.

Arcane Shield is a separate pool that only absorbs Elemental damage after mitigation. Physical damage bypasses it. The base recharge start delay is 3 seconds and the default recharge rate is 25% of maximum Arcane Shield per second.

```text
effective_recharge_start_delay = 3 / (1 + arcane_shield_recharge_start_speed / 100)
```

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
