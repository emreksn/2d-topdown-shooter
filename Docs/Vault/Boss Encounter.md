# Boss Encounter

> [!info] Status
> MVP implemented.

A Boss Encounter adds a boss to a wave. Bosses have large effective health pools, dangerous attacks, and dedicated loot tables. They are intended to create high-pressure fights and act as checks on the player's build and execution.

## Current implementation

- The first implemented boss is Charger Brute.
- Charger Brute is forced on every tenth wave.
- After wave 10 is completed, Boss Encounter can appear as optional [[Content]] for non-milestone waves.
- Boss content does not stack with forced milestone bosses in the MVP.
- Bosses use existing monster reward math with boosted reward, item quantity, item rarity, Relic drop, Weapon drop, and Active Skill drop values instead of dedicated boss loot tables.
- A boss health bar appears while the boss is alive.

## Appearance

Bosses appear at fixed milestones every tenth wave. A player may also add a boss through the content-selection screen after completing wave 10.

## Wave integration

A boss does not pause normal wave spawning. It enters after the wave begins, followed by a short delay before ordinary enemy spawning resumes. This grace period gives the player time to identify the boss, reposition, and form a strategy.

In the MVP, the boss spawns after a short warning while normal wave spawning continues.

## Charger Brute

Charger Brute is a large melee boss. It chases the player slowly, pauses to telegraph a straight charge, charges toward the player's sampled position, then enters a recovery window before resuming pursuit.

## Rewards

Bosses do not guarantee particular drops. Their loot uses the same underlying model as rare monsters with substantially increased item rarity, item quantity, and special drop chances.

> [!note] Balance target
> A value around 10x a rare monster's rarity and quantity is an initial placeholder, not a final balance value.

## Design goals

- Make bosses mechanically distinct from ordinary enemies.
- Telegraph dangerous attacks clearly.
- Reward the additional risk with concentrated, recognizable loot.
