# Hellforge Gauntlet

> [!info] Status
> Planned content; not yet implemented.

The Hellforge Gauntlet is a wave-based encounter focused on collecting Essence of Hell. Before each wave, the player chooses a Hell Pact that increases Essence gain while making the encounter more dangerous.

## Encounter configuration

The source that grants the encounter determines its length, for example: `Adds a 6-wave Hellforge Gauntlet to the next wave.`

The gauntlet ends with one or more [[Hellmaster|Hellmasters]]. The planned initial range is two to five Hellmasters, with the exact count scaling with gauntlet length and accumulated Essence.

## Core loop

1. Choose a Hell Pact.
2. Clear the empowered wave.
3. Accumulate Essence of Hell.
4. Repeat while risk and rewards escalate.
5. Defeat every spawned Hellmaster.
6. Use the [[Hellforge]].

## Failure and withdrawal

The player may end the gauntlet early to avoid dying, but receives no rewards. Dying also loses all gauntlet progress and rewards.

## Essence of Hell

Essence is an encounter score rather than a spendable currency. More Essence makes the Hellmasters stronger, improves their loot, allows the Hellforge to accept higher item rarities, and may allow stronger tiers of [[Hellforged Modifier|Hellforged Modifiers]] to roll.
