# Active Skills

> [!info] Status
> Early playable foundation implemented.

Active Skills are player-triggered abilities used during combat.

Future Active Skills can use [[Weapon System|weapon tags]] for compatibility checks, such as requiring `projectile`, `melee`, or `pistol`.

## Current implementation

- The player has two Active Skill slots.
- Slot 1 is bound to `Q`.
- Slot 2 is bound to `E`.
- Skill cooldown and active-channel state are shown on the player HUD.
- The first playable skills are Bulletstorm Volley and Dash.

## Current skills

### Bulletstorm Volley

Bulletstorm Volley is a channeled movement skill inspired by Diablo 3's Strafe.

For the full channel duration, the skill uses the player's attack rate with 500% more attack rate and deals 25% less damage. Projectile weapons are forced to fire exactly one projectile per attack while Bulletstorm Volley is active, ignoring shotgun pellets or other extra-projectile behavior.

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

### Dash

Dash is a fixed-cooldown movement skill. It moves the player through a short timed velocity burst instead of teleporting instantly.

Current tuning:

- 220 unit dash distance.
- 0.16 second dash duration.
- 4 second cooldown.

## Acquisition

An Active Skill may be:

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
