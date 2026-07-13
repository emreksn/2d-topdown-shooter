# Boss Encounter

> [!info] Status
> Planned content; not yet implemented.

A Boss Encounter adds a boss to a wave. Bosses have large effective health pools, dangerous attacks, and dedicated loot tables. They are intended to create high-pressure fights and act as checks on the player's build and execution.

## Appearance

Bosses appear at fixed milestones, such as every tenth wave. A player may also add a boss through the content-selection screen or an item modifier.

## Wave integration

A boss does not pause normal wave spawning. It enters after the wave begins, followed by a short delay before ordinary enemy spawning resumes. This grace period gives the player time to identify the boss, reposition, and form a strategy.

## Rewards

Bosses do not guarantee particular drops. Their loot uses the same underlying model as elite monsters with substantially increased item rarity and quantity.

> [!note] Balance target
> A value around 10× an elite's rarity and quantity is an initial placeholder, not a final balance value.

## Design goals

- Make bosses mechanically distinct from ordinary enemies.
- Telegraph dangerous attacks clearly.
- Reward the additional risk with concentrated, recognizable loot.
