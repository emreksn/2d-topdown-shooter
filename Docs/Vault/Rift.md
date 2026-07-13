# Rift

> [!info] Status
> Prototype implemented. Content selection is implemented. Dedicated Rift rewards are not yet implemented.

Rifts are small, unstable portals that appear at predetermined locations during a wave. Each portal spawns a group of Rift monsters and then vanishes. Multiple Rifts may open during one wave.

## Current implementation

- The [[Content]] choice screen can apply Rift to the next wave.
- Rift Content currently adds three portals with three monsters per portal.
- Wave definitions still support direct portal counts, but base prototype waves no longer force Rifts directly.
- Each wave selects portal positions from six authored spawn markers.
- A marker is used at most once during that wave.
- Portals open at intervals throughout the wave.
- Rift monsters use the wave's enemy pool and receive the `rift` context tag.
- Rift monsters do not consume the normal wave spawn budget.
- Rift monsters use the standard spawn indicators before appearing.
- Rift monsters are tracked as required active enemies and count toward wave cleanup.
- The supplied portal artwork is rendered behind actors, above the arena floor, with an animated pulse and background-removal shader.
- The first portal opens about two seconds after a wave starts so the mechanic is immediately visible during testing.

## Encounter rules

- Rifts have no separate timer, kill quota, stability meter, or completion reward.
- Portals exist only to spawn additional monsters.
- All rewards drop from the spawned monsters.
- The additional enemies increase both the danger and reward of the normal wave.

## Modifiers

Rift modifiers are supplied by the Content choice screen. They stack with applicable normal monster modifiers.

For example, if all monsters have 20% increased item rarity and Rift monsters have another 20%, Rift monsters receive 40% increased item rarity.

Current Rift variants:

- Stable Rift: no extra modifiers.
- Prosperous Rift: 60% increased gold granted by Rift monsters; 20% decreased experience granted by Rift monsters.
- Blessed Rift: 60% increased experience granted by Rift monsters; 20% decreased gold granted by Rift monsters.
- Bountiful Rift: 45% increased item quantity for Rift monsters; 35% increased monster item rarity for Rift monsters; 25% increased Rift monster maximum health; 10% increased Rift monster melee damage.
- Infested Rift: +1 Rift portal; +2 Rift monsters per portal; 20% decreased gold granted by Rift monsters; 20% decreased experience granted by Rift monsters.

Apex Rift is planned for elite-focused Rift content, but it is not currently in the offer pool.

Each Rift offer also rolls one extra modifier from the [[Content]] extra modifier pool. Extra modifiers are shown separately from the variant's inherent grants in the Content choice UI.

## Purpose

Rifts are primarily used to farm generic gold and experience, helping the player buy items from the shop and stabilize a build.
