# Items

> [!info] Status
> First normal item content pass implemented.

Items are stackable run upgrades bought from the shop or earned from reward systems. They use rarity bands, not upgrade tiers. The lower rarity bands should contain more items with smaller, simpler stats; higher rarity bands can use larger values or more advanced combinations.

[[Weapon System|Weapons]] are separate from normal stackable items. Weapons can appear in the shop, but they equip into weapon slots instead of entering the item inventory.

## Rarity distribution

The first normal item pool uses this quantity target:

- Common: 12 items.
- Uncommon: 6 items.
- Rare: 2 items.
- Legendary: 1 item.

Tradeoff and Unique are reserved for more complex future content and Relics. They are not part of this normal item pass.

## Rarity wave locks

Item rarity has one global wave-lock table shared by all item sources. Locked rarities have zero roll weight and cannot appear until their minimum wave.

- Common: wave 1.
- Uncommon: wave 1.
- Rare: wave 3.
- Legendary: wave 6.
- Tradeoff: wave 8.
- Unique: wave 10.

## Current normal item pool

### Common

- Running Shoes: 8% increased movement speed.
- Leather Padding: +10 to maximum health.
- Iron Nail: +4 to physical damage.
- Ember Shard: +3 to fire damage.
- Copper Coil: +3 to lightning damage.
- Frost Chip: +3 to cold damage.
- Practice Manual: 6% increased damage.
- Quick Fingers: 35% increased attack rate.
- Smooth Powder: 6% increased projectile speed.
- Scout Lens: 9% increased targeting range.
- Long Barrel: 11% increased targeting range.
- Small Magnet: 18% increased pickup range.

### Uncommon

- Loot Magnet: 39% increased pickup range.
- Battle Gloves: 12% increased damage; 25% increased attack rate.
- Reinforced Vest: +18 to maximum health; +8% to toughness.
- Hot Lead: +8 to fire damage.
- Keen Sights: 15% increased targeting range; 9% increased projectile speed.
- Runner's Belt: 12% increased movement speed; 5% increased attack rate.

### Rare

- Study Notes: 16% increased experience gain.
- Hunter's Ledger: 25% increased shop item rarity; 15% increased monster item rarity.

### Legendary

- Singularity Rounds: 30% increased damage; 20% increased attack rate; 16% increased projectile speed; 20% increased shop item rarity.

## Design notes

- Avoid suffixes like I, II, T1, or T2 for normal item progression.
- Common items should mostly be single-stat and easy to read.
- Uncommon items can combine two modest stats or give a stronger focused stat.
- Rare and Legendary items can influence build direction or reward systems.
- Relics remain separate from normal stackable items.
- Weapons remain separate from normal stackable items.
- UI stat lines are generated from modifiers and should use `X% increased ...`, `X% decreased ...`, `X% more ...`, `X% less ...`, or `+... to ...`. Each modifier is displayed on its own line.

## Shop behavior

- The shop offers 3 items by default.
- Shop offers can include normal items, Relics, or weapons.
- Bought items leave an empty shop slot until the next reroll or shop refresh.
- Bought weapons equip into the first empty weapon slot. If both weapon slots are full, weapon offers are blocked until a slot is freed.
- Rerolling costs gold and increases in cost for each reroll during the same shop phase.
- Locked offers survive rerolls and remain locked with their current price into the next shop phase until bought or unlocked.
- Relic offers cannot be bought while their matching active Relic slot is occupied.
- Opening inventory during an active wave pauses the game. Shop controls are only available during the shop phase.

## Shop stats

- `shop_extra_offer_count`: flat extra shop offer count. A future unique item can use `+1` to raise the shop from 3 offers to 4.
- `shop_reroll_cost_multiplier`: supports increased and more modifiers; negative values can reduce or lessen reroll cost.
- `shop_free_reroll_chance`: supports flat, increased, and more modifiers for chance to reroll for free. The player must still be able to afford the current reroll cost before the free reroll chance is rolled.

## Monster drops

Monsters can now roll item drops on death. The monster item pool can contain both normal Items and Relics, and both use the same item-drop chance. Rolled drops appear as visible world pickups during the wave.

When item drops are collected, they are queued for post-wave item evaluation instead of immediately entering the inventory. After wave auto-collect finishes, the player reviews each dropped item or Relic before level-up choices and shop.

Monster drops use the current shop item pool as a fallback pool until a dedicated monster drop pool is authored.
