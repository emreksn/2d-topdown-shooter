# Level Ups

> [!info] Status
> Early playable foundation implemented.

Level-ups should offer stat choices during a run. These choices are separate from shop [[Items]] and [[Relics]]: they are direct character growth, not inventory items.

When the player levels up, the choice is queued instead of shown immediately. After a wave ends and end-wave rewards are collected, pending level-up choices are resolved before the shop opens. If multiple levels are gained at once, each level-up choice is resolved one at a time.

Each level-up presents 3 options. Choosing an option applies a permanent run modifier directly to the player or current weapons. These are not inventory items.

## Candidate stat pools

### Common

- +5 to maximum health.
- 5% increased damage.
- 10% increased attack rate.

### Uncommon

- +10 to maximum health.
- 10% increased damage.
- 20% increased attack rate.
- 5% increased movement speed.
- 8% increased item rarity.

### Rare

- +20 to maximum health.
- 18% increased damage.
- 35% increased attack rate.
- 10% increased movement speed.
- 15% increased item rarity.
- 15% increased experience gain.
- 15% increased gold gain.

### Legendary

- +35 to maximum health.
- 30% increased damage.
- 60% increased attack rate.
- 18% increased movement speed.
- 25% increased item rarity.
- 25% increased experience gain.
- 25% increased gold gain.
- +15% to free reroll chance. See the shop rule in [[Items]].

## Rarity weighting

Level-up option rarity uses a simple weighted roll for each offered choice:

- Common: 64%.
- Uncommon: 24%.
- Rare: 10%.
- Legendary: 2%.

Duplicate stat choices are avoided within the same offer set when possible.
