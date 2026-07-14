# Active Skills

> [!info] Status
> Early playable foundation implemented.

Active Skills are player-triggered abilities used during combat.

Active Skills can declare weapon dependencies. A skill may require weapon tags, supported base damage types, or no weapon at all. Weapon-bound skills store a selected eligible weapon slot, and the HUD shows weapon selection buttons when more than one equipped weapon is eligible.

## Current implementation

- The player has two Active Skill slots.
- Slot 1 is bound to `Q`.
- Slot 2 is bound to `E`.
- After choosing a starter weapon, the player chooses two starter Active Skills consecutively, one slot at a time.
- Starter skill choices are filtered by the chosen weapon's eligibility. For example, a Physical projectile weapon can support Bulletstorm Volley, while an Elemental weapon can support Frost Nova.
- Skill cooldown, active-channel state, and weapon binding choices are shown on the player HUD.
- The first playable skills are Bulletstorm Volley, Dash, and Frost Nova.

## Current skills

### Bulletstorm Volley

Bulletstorm Volley is a channeled movement skill inspired by Diablo 3's Strafe.

For the full channel duration, the skill uses the player's attack rate with 500% more attack rate and deals 25% less damage. Projectile weapons are forced to fire exactly one projectile per attack while Bulletstorm Volley is active, ignoring shotgun pellets or other extra-projectile behavior.

Bulletstorm Volley requires a Physical ranged weapon. In the current weapon model, ranged means the weapon has the `projectile` tag and Physical support means the weapon can read Physical base damage. If two eligible weapons are equipped, the player can choose which weapon casts the volley.

Bulletstorm Volley fires through the selected weapon, so that weapon's local projectile, damage, targeting, pierce, fork, chain, and other normal weapon stats apply naturally. During the channel, the selected weapon's attack context also gains `active_skill` and `bulletstorm_volley` tags. This lets weapon-local modifiers target Bulletstorm specifically, for example `increased projectile speed while bulletstorm_volley`.

Targeting divides the player's targeting range into 12 pizza-slice sectors. The first sector is centered above the player.

Each channel creates a randomized sector bag. A sector can be selected only once until all sectors have been used, then the bag refills and every sector becomes eligible again. This keeps the volley distributed around the player without following a robotic clockwise or counter-clockwise pattern.

For each shot, the skill checks enemies inside the selected sector. Each enemy gets a 50% chance to be selected, checked one at a time until one succeeds. If no enemy succeeds, the projectile fires in a random direction inside that sector, making the skill miss by design.

Bulletstorm Volley currently prints debug lines for targeted shots, random sector shots, projectile hits, and projectile misses.

Current tuning:

- 4 second channel.
- 12 second cooldown.
- Uses player attack rate.
- 500% more attack rate.
- 25% less damage.
- Exactly one projectile per attack.
- 12 targeting sectors.
- 50% chance per enemy in the active sector.
- Randomized sector bag: all sectors fire once before any sector repeats.
- Console debug output enabled.
- Requires an eligible Physical projectile weapon.
- Selected weapon attacks gain `active_skill` and `bulletstorm_volley` tags during the channel.

### Dash

Dash is a fixed-cooldown movement skill. It moves the player through a short timed velocity burst instead of teleporting instantly.

Dash has no weapon dependency and does not show weapon binding choices.

Current tuning:

- 220 unit dash distance.
- 0.16 second dash duration.
- 4 second cooldown.
- No weapon requirement.

### Frost Nova

Frost Nova is an immediate elemental radius skill. It deals Elemental damage around the player and applies Slow.

Frost Nova requires an Elemental weapon. The weapon can be melee or ranged; current eligibility is satisfied by weapons that support Elemental base damage, such as Wand. If multiple eligible Elemental weapons are equipped, the player chooses which weapon Frost Nova is cast with.

Frost Nova spawns a short expanding ice ring visual at the player. The visual uses the same resolved radius as the hit check, so inherited Area of Effect modifiers are reflected on-screen.

Frost Nova inherits selected weapon local modifiers for relevant skill stats:

- `damage` and `elemental_damage` scale the nova damage.
- `area_of_effect` scales the nova radius.

It does not directly add the selected weapon's flat/base damage to the nova; the skill keeps its own base damage and player-added Elemental scaling.

Current tuning:

- 18 base Elemental damage.
- 50% Elemental damage scaling from player-added Elemental damage.
- 260 unit radius.
- 25% Slow.
- 2.5 second Slow duration.
- 8 second cooldown.
- Requires an eligible Elemental weapon.

## Acquisition

An Active Skill may be:

- Chosen during the starter skill selection after the starter weapon is selected.
- Bound to a weapon.
- Purchased from a shop.
- Dropped as a reward from [[Content]].

## Loadout rules

- The player may equip a maximum of two Active Skills during a wave.
- Equipped Active Skills are locked while the wave is active.
- The player may change equipped Active Skills between rounds at no cost.

This creates commitment within each wave while allowing the player to adapt their loadout for upcoming threats.

## Skill costs

Active Skills use cooldowns and have no resource cost by default. Individual skills may use charges or other resources as exceptions in the future.
