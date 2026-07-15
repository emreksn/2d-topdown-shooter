# Items

> [!info] Status
> First normal item content pass implemented.

Items are stackable run upgrades bought from the shop or earned from reward systems. They use rarity bands, not upgrade tiers. The lower rarity bands should contain more items with smaller, simpler stats; higher rarity bands can use larger values or more advanced combinations.

[[Weapon System|Weapons]] are separate from normal stackable items. Weapons can appear in the shop, but they equip into weapon slots instead of entering the item inventory.

Weapon base variants can share a weapon family while carrying different implicits. For example, Chilling Pistol, Forking Pistol, and Chaining Pistol all count as Pistols but have different guaranteed base modifiers before rarity scaling and generated affixes.

Weapon offers can roll generated affixes that grant projectile behaviors. Pierce, Fork, and Chain are weapon stats, so future Items or Relics can also grant them through normal modifier sets targeting the `weapon` domain.

Weapon damage-type modifiers still respect each weapon's allowed base damage types. Physical projectile weapons ignore flat Elemental damage as base damage, while Wand ignores flat Physical damage as base damage. Conversion or gain-as-extra mechanics can still create off-type damage explicitly.

## Rarity distribution

The current normal item pool uses this quantity spread:

- Common: 13 items.
- Uncommon: 9 items.
- Rare: 9 items.
- Legendary: 4 items.
- Unique: 2 items.

Tradeoff items are reserved for more complex future content and Relics. Unique normal items are now used for build-defining mechanics.

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
- Elemental Shard: +3 to elemental damage.
- Iron Plates: +24 to armour.
- Silk Treads: +24 to evasion.
- Ward Pebble: +10 to maximum arcane shield.
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
- Tempered Plates: 8% increased armour.
- Ghostweave Thread: 8% increased evasion.
- Ward Etching: 8% increased maximum arcane shield.
- Hot Lead: +8 to elemental damage.
- Keen Sights: 15% increased targeting range; 9% increased projectile speed.
- Runner's Belt: 12% increased movement speed; 5% increased attack rate.

### Rare

- Study Notes: 16% increased experience gain.
- Hunter's Ledger: 25% increased shop item rarity; 15% increased monster item rarity.
- Expanding Sigils: 22% increased area of effect.
- Clockwork Focus: 12% decreased cooldown duration.
- Truesight Lens: +140 to accuracy.
- Phase Needle: +10% to physical resistance penetration.
- Null Shard: +10% to elemental resistance penetration.
- Ward Dynamo: +15% to arcane shield recharge rate.
- Quickening Ward: +50% to arcane shield recharge start speed.

### Legendary

- Singularity Rounds: 30% increased damage; 20% increased attack rate; 16% increased projectile speed; 20% increased shop item rarity.
- Cosmic Geometry: 42% increased area of effect.
- Chrono Core: 24% decreased cooldown duration.
- Sundering Gauge: +220 to armour penetration; +80 to accuracy.

### Unique

- Chain Reactor: +1 to projectile chain.
- Fork Stabilizer: forked projectiles deal no less damage, but it does not grant Fork by itself.

## Design notes

- Avoid suffixes like I, II, T1, or T2 for normal item progression.
- Common items should mostly be single-stat and easy to read.
- Uncommon items can combine two modest stats or give a stronger focused stat.
- Rare and Legendary items can influence build direction or reward systems.
- Unique items should create or complete build identities. They can be narrow, but should be memorable.
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

## Weapon behavior stats

These stats are available to generated weapon affixes and future Item or Relic modifiers:

- `projectile_pierce`: flat extra projectile pierce count.
- `projectile_fork`: flat extra projectile fork count.
- `projectile_chain`: flat extra projectile chain count.
- `projectile_chain_radius`: flat extra chain search radius.
- `slow_chance`: flat Slow application chance.
- `slow_magnitude`: flat Slow magnitude.
- `slow_duration`: flat Slow duration.
- `area_of_effect`: increased or more Area of Effect for compatible skills.
- `cooldown_duration`: negative increased values reduce active skill cooldown duration.

Forked projectile damage is handled through a `MORE` damage modifier with the `forked` tag. The current default fork penalty is `MORE -30% damage`.

## Monster drops

Monsters can now roll drops on death. The monster drop model can produce normal Items, Relics, Weapons, and Active Skills. Rolled drops appear as visible world pickups during the wave.

When drops are collected, they are queued for post-wave evaluation instead of immediately entering the inventory. After wave auto-collect finishes, the player reviews each dropped Item, Relic, Weapon, or Active Skill before level-up choices and shop.

Relic drops are not stored in the normal item inventory. Keeping a Relic equips it into its slot, replacing the current active Relic in that slot if one is already equipped. Selling a dropped Relic grants gold instead.

Monster item and relic drops use the current shop item pool as a fallback pool until a dedicated monster drop pool is authored. Monster weapon drops use the current shop weapon pool as a fallback pool. Monster Active Skill drops use the starter skill pool as a fallback pool.

Current monster drop chance stats:

- `monster_item_rarity_multiplier`: increases the rarity of dropped Items, Relics, and Weapons.
- `monster_relic_drop_chance_multiplier`: increases chance to drop Relics.
- `monster_weapon_drop_chance_multiplier`: increases chance to drop Weapons.
- `monster_active_skill_drop_chance_multiplier`: increases chance to drop Active Skills.
