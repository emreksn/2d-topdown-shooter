# Weapon System

> [!info] Status
> Early loadout and shop foundation implemented.

Weapons are nodes that automatically target enemies and perform basic attacks. Weapon stats use the `weapon` stat domain and resolve modifiers through contextual tags.

The player has two usable weapon slots. A run starts with a common weapon choice, and additional weapons are acquired from the shop.

## Current implementation

- `Weapon` is the base weapon script.
- `ProjectileWeapon` is the shared base for projectile-firing weapons.
- `Pistol`, `Machine Gun`, and `Shotgun` are the first authored normal weapons.
- `OP Test Pistol` is a temporary testing weapon and is not part of normal shop rolls.
- `WeaponDefinition` resources provide weapon metadata.
- `WeaponOffer` resources represent rolled shop weapons with rarity scaling and generated affixes.
- `WeaponLoadoutComponent` owns the player's two equipped weapon slots.
- The current projectile weapon definitions use `weapon`, `projectile`, and a weapon-family tag.

Weapon attack context always includes the system tag `attack`. The Pistol therefore resolves attack stats and damage with `attack`, `weapon`, `projectile`, and `pistol`.

## Loadout rules

- The player has exactly two weapon slots.
- The starter weapon choice appears at the beginning of a run and offers common Pistol, Machine Gun, Shotgun, and the temporary OP Test Pistol.
- Choosing a starter weapon equips it into slot 1. Slot 2 starts empty.
- Buying a weapon from the shop equips it into the first empty slot, starting from slot 1.
- If both weapon slots are full, shop weapon offers are blocked until the player sells an equipped weapon.
- Equipped weapons can be sold from the shop/inventory UI to free their slot.

Weapons are shop-only in the current design. They are not normal stackable items, and they are not monster drops.

## Current weapons

- Pistol: `weapon`, `projectile`, `pistol`.
- Machine Gun: `weapon`, `projectile`, `machine_gun`.
- Shotgun: `weapon`, `projectile`, `shotgun`.
- OP Test Pistol: `weapon`, `projectile`, `pistol`, `op_test_pistol`.

Current common tuning:

- Pistol: one projectile, moderate single-shot damage, slow attack rate.
- Machine Gun: one projectile, low per-shot damage, moderate attack rate.
- Shotgun: four projectiles, lower per-projectile damage, very slow attack rate, narrow randomized spread.

## Rarity

Weapons use the same rarity bands and wave locks as [[Items]], but they are not item inventory entries.

Current weapon rarity scaling:

- Common: `1.00x` base weapon stats and 0 affixes.
- Uncommon: `1.25x` base weapon stats and 1 affix.
- Rare: `1.60x` base weapon stats and 2 affixes.
- Legendary: `2.10x` base weapon stats and 3 affixes.

Tradeoff and Unique weapons are not part of the current weapon pass.

Generated weapon affixes roll from core weapon stats:

- Physical damage.
- Fire damage.
- Lightning damage.
- Cold damage.
- Attack rate.
- Targeting range.
- Projectile speed.

Duplicate affix stats are avoided on the same weapon when possible.

Projectiles despawn when they hit, when they leave the arena bounds, or when an internal failsafe timer expires. Projectile lifetime is not a player-facing stat.

## Weapon tags

Weapon tags describe weapon identity and delivery style. They are intended for stat filtering and future compatibility checks.

Examples:

- `weapon`: the action came from a weapon.
- `projectile`: the weapon delivers attacks through projectiles.
- `pistol`: the specific weapon family.
- `machine_gun`: the specific weapon family.
- `shotgun`: the specific weapon family.
- `melee`: planned for weapons that deliver melee attacks.

The `hit` tag is not a weapon tag. It represents a hit or damage-resolution event, such as a hurtbox receiving damage or contact damage being applied.

## Active Skill compatibility

[[Active Skills]] are not implemented yet, but future skills can require weapon tags. For example, a projectile-only skill can require `projectile`, while a pistol-specific skill can require `pistol`.

## Related systems

- [[Combat System]]
- [[Stats and Modifiers]]
- [[Active Skills]]
- [[Items]]
