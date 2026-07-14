# Relics

> [!info] Status
> Early playable foundation implemented.

Relics are run-shaping items that sit outside normal gear. They are not equipment slots, and they do not stack like ordinary items. Each Relic belongs to one slot, and the player can have one active Relic per slot.

Relics are sellable by default. The shop blocks buying a Relic if that Relic's slot is already occupied. To replace a shop Relic, the player must first sell the active Relic in that slot.

## Relic slots

- Combat Relic: major combat-state fantasies, kill effects, rare-monster interaction rules, and enemy interaction rules.
- Weapon Relic: projectile, melee, attack pattern, firing behavior, chain, fork, split, cleave, and repeat-style changes.
- Economy Relic: gold, experience, item rarity, shop behavior, loot conversion, and wave-end reward rules.
- Survival Relic: health, shields, recovery, revives, mitigation, and defensive tradeoffs.
- Wave Relic: wave timers, spawn composition, encounter rules, rifts, events, and arena modifiers.

## Current implementation

- Relics use the same rarity system as items: common, uncommon, rare, legendary, tradeoff, unique.
- Relics can appear in the shop pool.
- Relics apply stat modifiers while active.
- One active Relic is allowed per slot.
- Shop purchases are blocked when the offered Relic's slot is already occupied.
- Active Relics can be sold directly from inventory.
- Shop Relic appearance is affected by Relic Chance Multiplier and Shop Relic Chance Multiplier.
- Monster drops do not use a separate Relic chance; Relics roll through the same item-drop path as normal items.

## Starter Relics

- Head-Taker Crown: Combat Relic.
- Splintering Chamber: Weapon Relic.
- Emberglass Prism: Weapon Relic; gain 25% of Physical damage as extra Elemental damage.
- Ironwood Icon: Combat Relic; gain 25% of Elemental damage as extra Physical damage.
- Pinata Pact: Economy Relic.
- Last Breath Locket: Survival Relic.
- Rift Compass: Wave Relic.

## Design notes

Weapon Relics are intentionally separated from Combat Relics. This lets players take fun projectile or melee behavior changes without giving up major run-fantasy effects such as Headhunter-like combat Relics.

Relics can also carry `DamageConversion` resources. Current authored examples use `GAIN_AS_EXTRA`, letting a build gain one damage type from another without consuming the source damage.
