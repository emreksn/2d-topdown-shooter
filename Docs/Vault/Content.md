# Content

Content is the umbrella term for special encounters and activities that can appear during a run or be accessed through endgame systems. Each content type has its own mechanics, rewards, and risk structure.

Content should provide optional goals beyond clearing ordinary waves. Its rewards should give players a reason to seek particular encounters depending on the needs of their build.

## Selection and acquisition

After shopping and before the next wave, the player is offered Content options and may instead choose **No extra content**. The current implementation offers one Content option because [[Rift]] is the only implemented Content type.

Items can also force Content onto the next wave through modifiers such as `Adds a Rift to the next wave`. Forced Content bypasses the ordinary choice for that wave.

> [!question] Draft rule
> The current direction is a maximum of one Content encounter per wave, but this limit is still open for discussion.

## Current implementation

- `ContentManager` owns the available Content pool and selected Content for upcoming waves.
- The wave flow is end-wave cleanup, level-up choices, shop, Content choice, preparation, then the next wave.
- The selected Content is applied to a duplicated `WaveDefinition` for the next wave, leaving base wave resources clean.
- The current Content choice screen rolls modified [[Rift]] offers and **No Extra Content**.
- Base waves no longer force Rift portals directly.

## Content variants

Content offers are built as `Variant + Content`, such as `Prosperous Rift` or `Infested Rift`.

The variant supplies the offer's inherent modifiers. The Content supplies the encounter mechanics. One compatible extra modifier is currently rolled onto each Content offer.

Current variant identities:

- Stable: baseline, no extra modifiers.
- Prosperous: gold-focused.
- Blessed: experience-focused.
- Bountiful: item quantity and item rarity-focused.
- Infested: more normal monster spawns.
- Apex: planned for elite-focused content, not currently in the offer pool.

## Extra modifiers

Extra modifiers are separate rolled modifiers that can be pure upside, risk-reward, or hybrid.

Current Rift extra modifier pool:

- Golden Wake: 20% increased gold granted by Rift monsters.
- Bright Wake: 20% increased experience granted by Rift monsters.
- Lucky Wake: 20% increased monster item rarity for Rift monsters.
- Crowded Wake: +1 Rift monster per portal.
- Hardened Cache: 20% increased Rift monster maximum health; 30% increased gold granted by Rift monsters.
- Painful Lessons: 15% increased Rift monster melee damage; 30% increased experience granted by Rift monsters.
- Frantic Pack: +2 Rift monsters per portal; 10% increased Rift monster movement speed.
- Gilded Lessons: 25% increased gold granted and 25% increased experience granted by Rift monsters.
- Heavy Hoard: 30% increased item quantity for Rift monsters; 15% increased Rift monster maximum health.
- Violent Abundance: 25% increased monster item rarity for Rift monsters; 15% increased Rift monster melee damage.
- Crowded Treasury: +1 Rift monster per portal; 15% increased gold granted by Rift monsters.
- Pressed Offering: +1 Rift portal; 20% increased Rift monster maximum health; 20% increased experience granted by Rift monsters.

## Content types

- [[Rift]] — generic gold and experience.
- [[Ancient Ritual]] — ritual-specific unique items and item-modifying currencies.
- [[Boss Encounter]] — concentrated items, gold, and experience.
- [[Hellforge Gauntlet]] — Essence of Hell, Hellmaster loot, and access to the Hellforge.
- [[The Tower]] — escalating item modification and Tower currencies.

## Shared design goals

- Each content type should be visually and mechanically recognizable.
- Risk should scale alongside rewards.
- Content-specific rewards should preserve each encounter's identity.
- Entering or continuing content should involve a meaningful player decision.
