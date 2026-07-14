# Weapon System

> [!info] Status
> Early loadout and shop foundation implemented.

Weapons are nodes that automatically target enemies and perform basic attacks. Weapon stats use the `weapon` stat domain and resolve modifiers through contextual tags.

The player has two usable weapon slots. A run starts with a common weapon choice, and additional weapons are acquired from the shop.

## Current implementation

- `Weapon` is the base weapon script.
- `ProjectileWeapon` is the shared base for projectile-firing weapons.
- `Pistol`, `Machine Gun`, `Shotgun`, and `Wand` are the first authored normal weapons.
- `OP Test Pistol` is a temporary testing weapon and is not part of normal shop rolls.
- `WeaponDefinition` resources provide weapon metadata and optional base implicits.
- `WeaponOffer` resources represent rolled shop weapons with rarity scaling and generated affixes.
- `WeaponLoadoutComponent` owns the player's two equipped weapon slots.
- The current projectile weapon definitions use `weapon`, `projectile`, and a weapon-family tag.

Weapon attack context always includes the system tag `attack`. The Pistol therefore resolves attack stats and damage with `attack`, `weapon`, `projectile`, and `pistol`.

## Loadout rules

- The player has exactly two weapon slots.
- The starter weapon choice appears at the beginning of a run and offers common weapon bases, including Pistol variants, Machine Gun, Shotgun, Wand, and the temporary OP Test Pistol.
- Choosing a starter weapon equips it into slot 1. Slot 2 starts empty.
- Buying a weapon from the shop equips it into the first empty slot, starting from slot 1.
- If both weapon slots are full, shop weapon offers are blocked until the player sells an equipped weapon.
- Equipped weapons can be sold from the shop/inventory UI to free their slot.

Weapons are shop-only in the current design. They are not normal stackable items, and they are not monster drops.

## Current weapons

- Pistol: `weapon`, `projectile`, `pistol`.
- Chilling Pistol: `weapon`, `projectile`, `pistol`, `slow`.
- Forking Pistol: `weapon`, `projectile`, `pistol`, `fork`.
- Chaining Pistol: `weapon`, `projectile`, `pistol`, `chain`.
- Machine Gun: `weapon`, `projectile`, `machine_gun`.
- Shotgun: `weapon`, `projectile`, `shotgun`.
- Wand: `weapon`, `projectile`, `wand`, `elemental`.
- OP Test Pistol: `weapon`, `projectile`, `pistol`, `op_test_pistol`.

Current common tuning:

- Pistol: one projectile, 30 Physical base damage, slow attack rate.
- Chilling Pistol: Pistol base with implicit Slow delivery.
- Forking Pistol: Pistol base with implicit +1 Fork.
- Chaining Pistol: Pistol base with implicit +1 Chain.
- Machine Gun: one projectile, 15 Physical base damage, moderate attack rate.
- Shotgun: four projectiles, 18 Physical base damage per projectile, very slow attack rate, narrow randomized spread.
- Wand: one slower projectile, 30 Elemental base damage, moderate attack rate.

Current early-game clean-kill targets use 90 base health for basic enemies and 60 base health for ranged enemies. Pistol and Wand cleanly kill basic enemies in 3 hits and ranged enemies in 2 hits. Machine Gun cleanly kills basic enemies in 6 hits and ranged enemies in 4 hits.

## Base damage type rules

Projectile weapons filter which flat/base damage type stats they can read:

- Pistol, Machine Gun, Shotgun, and OP Test Pistol read Physical base damage only.
- Wand reads Elemental base damage only.

This means Wand ignores flat `physical_damage` as base damage, and physical projectile weapons ignore flat `elemental_damage` as base damage. Damage conversion and gain-as-extra effects can still create other damage types after the allowed base damage is gathered. For example, an elemental Wand can still gain extra Physical damage through a conversion/gain mechanic that explicitly creates Physical damage.

Projectile weapons also have a backend `added_damage_multiplier` export. Outgoing weapon hit damage is built per allowed damage type as:

```text
weapon_hit_damage = weapon_local_base_damage + resolved_actor_added_damage x added_damage_multiplier
```

`resolved_actor_added_damage` is the actor's matching flat added damage after applicable global increased and more damage modifiers. The multiplier is not an end-user named stat yet; it is a weapon tuning value that lets weapon bases scale player-added damage differently. Current initial values are Pistol `1.5`, Machine Gun `0.85`, Shotgun `0.45` per pellet, Wand `1.25`, and OP Test Pistol `1.5`.

## Rarity

Weapons use the same rarity bands and wave locks as [[Items]], but they are not item inventory entries.

Weapon base variants are separate `WeaponDefinition` resources that can share a family tag and weapon scene. For example, Chilling Pistol, Forking Pistol, and Chaining Pistol all count as Pistols because they keep the `pistol` tag, but each has its own implicit modifier set. Implicits are added before rarity scaling and generated affixes, and they appear separately in weapon offer text.

Current weapon rarity scaling:

- Common: `1.00x` base weapon stats and 0 affixes.
- Uncommon: `1.25x` base weapon stats and 1 affix.
- Rare: `1.60x` base weapon stats and 2 affixes.
- Legendary: `2.10x` base weapon stats and 3 affixes.

Tradeoff and Unique weapons are not part of the current weapon pass.

Generated weapon affixes roll from core weapon stats:

- Physical damage.
- Elemental damage.
- Attack rate.
- Targeting range.
- Projectile speed.
- Projectile pierce.
- Projectile fork.
- Projectile chain.

Duplicate affix stats are avoided on the same weapon when possible.

Projectiles despawn or recycle when they finish resolving their behavior, when they leave the arena bounds, or when an internal failsafe timer expires. Projectile lifetime is not a player-facing stat.

## Projectile behaviors

Projectile weapons expose behavior values both as scene defaults and as weapon stats:

- `projectile_pierce`: number of targets the projectile can pass through after damaging.
- `projectile_fork`: number of times the projectile can split into two child projectiles.
- `projectile_chain`: number of times the projectile can redirect after a hit.
- `projectile_chain_radius`: search radius for Chain targeting.

Resolution priority is fixed:

```text
Pierce -> Fork -> Chain
```

Fork creates two non-targeted child projectiles in a Y shape based on `fork_angle_degrees`. Forked projectiles default to `30% less damage`, implemented as a `MORE -30% damage` modifier with the `forked` tag. The exported `fork_damage_multiplier` defines that modifier value; the default `0.7` becomes `MORE -30%`.

Chain redirects to another target inside `projectile_chain_radius`. It ignores targets the projectile has already hit.

## Status delivery

Projectile weapons can explicitly carry Slow delivery values:

- `slow_chance`
- `slow_magnitude`
- `slow_duration`

These exports default to zero, and matching weapon stats can add to them through local modifiers. Slow is not included in the generic generated weapon affix pool. Slow is intended to be unlocked by specific weapon bases, items, relics, or other status-lane content instead of being randomly accessible to every projectile build.

## Weapon tags

Weapon tags describe weapon identity and delivery style. They are intended for stat filtering and future compatibility checks.

Examples:

- `weapon`: the action came from a weapon.
- `projectile`: the weapon delivers attacks through projectiles.
- `forked`: the projectile is a child created by Fork and receives fork-specific modifiers.
- `pistol`: the specific weapon family.
- `slow`: a weapon base identity for Slow-focused variants.
- `fork`: a weapon base identity for Fork-focused variants.
- `chain`: a weapon base identity for Chain-focused variants.
- `machine_gun`: the specific weapon family.
- `shotgun`: the specific weapon family.
- `wand`: the specific weapon family.
- `elemental`: the weapon is authored as an elemental identity.
- `melee`: planned for weapons that deliver melee attacks.

The `hit` tag is not a weapon tag. It represents a hit or damage-resolution event, such as a hurtbox receiving damage or contact damage being applied.

## Active Skill compatibility

[[Active Skills]] have an early playable foundation. Future skills can require weapon tags. For example, a projectile-only skill can require `projectile`, while a pistol-specific skill can require `pistol`.

## Related systems

- [[Combat System]]
- [[Stats and Modifiers]]
- [[Active Skills]]
- [[Items]]
