# Combat System

> [!info] Status
> Implemented foundation.

Combat uses damage packets composed of one or more typed damage slices.

## Damage types

- Physical
- Elemental

Fire, cold, and lightning are no longer damage types. Future elemental flavor should be implemented as status or effect mechanics on top of Elemental damage.

## Status effects

Slow is implemented as the first status lane. It is not part of the generic generated weapon affix pool.

Slow has magnitude and duration:

- Movement speed is reduced by the slow magnitude through a temporary `MORE` movement-speed modifier on the monster.
- Slow magnitude is capped at `70%`.
- Slow refreshes by keeping the strongest active magnitude and longest remaining duration.

Slow also affects monster action speed at breakpoints:

```text
0-24% slow: movement speed only
25-49% slow: 15% action speed reduction
50%+ slow: 30% action speed reduction
```

Action speed reduction currently affects contact damage cooldowns and ranged enemy charge/cooldown timing. This keeps light Slow focused on kiting while heavier Slow suppresses monster actions.

Outgoing weapon damage supports flat [[Weapon System|weapon]] damage, actor-added damage, contextual tags, and damage conversion. Projectile weapons build each allowed damage type from local weapon base damage plus the actor's resolved matching added damage multiplied by the weapon's backend `added_damage_multiplier`.

Projectile weapons can filter which base damage type stats they read before conversion:

- Physical projectile weapons currently read only Physical base damage.
- Wand reads only Elemental base damage.

This base filter does not block later conversion or gain-as-extra effects from creating another damage type.

Conversion consumes source damage and can convert up to 100% of the source damage per conversion stage. Gain as extra creates additional destination-typed damage without consuming source damage. Gain is calculated from a frozen pre-gain source pool and cannot recursively gain from damage created by gain.

Actor increased and more damage modifiers affect actor-added damage before the weapon added-damage multiplier is applied. They do not globally amplify pure weapon local base damage through `build_outgoing_packet`.

Incoming damage is resolved through layered defenses:

1. Evasion, which can fully avoid the hit before any hit signals or damage reactions happen. Attacker Accuracy reduces the defender's Evasion rating before this chance is calculated.
2. Physical and Elemental resistance, capped by matching maximum resistance. Matching attacker Resistance Penetration subtracts from the capped effective resistance.
3. Deflection, which rolls if evasion fails and reduces the hit by the defender's Deflection Damage Reduction.
4. Armour, which reduces physical hit damage. Attacker Armour Penetration reduces the defender's Armour rating before this mitigation is calculated.
5. Toughness, which reduces remaining damage generically. Monster Effectiveness is added into Toughness before this formula instead of acting as a separate layer.
6. Arcane Shield, which absorbs final Elemental damage before health. Physical damage bypasses Arcane Shield.

Current rating formulas:

```text
effective_evasion = max(evasion - attacker_accuracy, 0)
evade_chance = 75% x effective_evasion / (effective_evasion + 500)
effective_resistance = max(min(resistance, maximum_resistance) - matching_penetration, -100%)
effective_armour = max(armour - attacker_armour_penetration, 0)
armour_reduction = 90% x effective_armour / (effective_armour + 800)
```

Evasion and Armour use rating-only soft-cap curves. Larger hits no longer directly reduce their chance or mitigation; counterplay comes from Accuracy, Resistance Penetration, and Armour Penetration.

Toughness uses one combined value:

```text
combined_toughness = toughness + monster_effectiveness
toughness_multiplier = 1 / (1 + combined_toughness / 100)
```

Arcane Shield recharges after its recharge start delay if it has not absorbed Elemental damage. The base delay is 3 seconds and is shortened by Arcane Shield Recharge Start Speed:

```text
effective_recharge_start_delay = 3 / (1 + arcane_shield_recharge_start_speed / 100)
```

The default recharge rate is 25% of maximum Arcane Shield per second.

## Current delivery methods

- Pistol projectiles.
- Projectile weapons can use Pierce, Fork, and Chain behavior.
- Projectile weapons can explicitly deliver Slow when configured by a specific weapon or future status-lane item/relic.
- Enemy melee damage.
- Ranged enemy projectiles.

Damage numbers provide hit feedback. Health is managed by reusable health and hurtbox components.

Evasion and Deflection also produce floating combat feedback. Evaded hits show `EVADED` and deal no damage. Deflected hits show `DEFLECTED` alongside the reduced damage number. This feedback is emitted through the shared Hurtbox/DamageNumberEmitter path, so it works for both player and monsters.

## Projectile behavior order

Projectile collision behavior resolves in this order after a valid enemy hit:

1. Pierce
2. Fork
3. Chain

Pierce lets a projectile pass through a damaged target and continue moving. A projectile tracks actors it has already hit so it does not repeatedly damage the same target while piercing, forking, or chaining.

Fork splits a projectile into two child projectiles in a Y shape the first time Fork resolves. Forked projectiles inherit the remaining projectile behavior state. By default, forked projectiles deal `30% less damage` through a `StatModifier.Operation.MORE` damage modifier with the `forked` tag, not through a raw damage-slice multiplier. The default exported fork damage multiplier is `0.7`, which is converted into `MORE -30% damage`.

Chain redirects a projectile to another valid target after a hit if Pierce and Fork did not resolve. Chain uses a radius search and excludes targets already hit by that projectile chain.

## Damage display

A single hit displays a separate color-coded number for each damage type it deals. The largest component uses the normal display size. Smaller components scale down relative to the largest, and components below 2% of the largest are omitted to avoid visual noise.

Displayed typed amounts are normalized to damage actually removed from health or Arcane Shield, so mitigation and overkill do not inflate the feedback.

## Object pooling

Hot combat nodes are pooled to reduce allocation spikes:

- Projectile weapons keep local projectile pools.
- SpawnDirector pools enemies by enemy scene.

Pooled projectiles reset hit state, lifetime, debug state, collision monitoring, and behavior counters before reuse. Pooled enemies reset health, collision, tweens, scale, alpha, rarity metadata, runtime modifier sources, child combat component state, and stat baselines before reuse.

## Related systems

- [[Stats and Modifiers]]
- [[Core Gameplay]]
- [[Weapon System]]
