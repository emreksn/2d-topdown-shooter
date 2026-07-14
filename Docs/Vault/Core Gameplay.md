# Core Gameplay

> [!info] Status
> Partially implemented.

## Current loop

1. Choose a starter [[Weapon System|weapon]] at run start.
2. Choose two starter [[Active Skills]] consecutively.
3. Prepare for the wave.
4. Fight while timed enemy spawning is active.
5. Clear remaining required enemies after spawning ends.
6. Auto-collect remaining drops.
7. Evaluate dropped items and [[Relics]].
8. Resolve queued [[Level Ups]].
9. Use the shop.
10. Select optional [[Content]] for the next wave.
11. Begin the next preparation phase.

The current build repeats the final configured wave definition, allowing the run to continue indefinitely.

## Player

The player has stat-driven movement speed and health. Death shows a short "You Died" overlay, pauses the run, then returns to the main menu. Movement uses a shader-based squash effect for visual feedback.

The player HUD displays numeric current/maximum health, total gold, level, and experience progress toward the next level.

Defeated monsters drop separate gold and experience pickups. Pickups move toward the player inside the player's Pickup Range, while Instant Pickup Chance can award either reward immediately.

## Arena

The current arena is a bounded 1600×1000 playfield. A bright cyan border communicates its edges, and collision walls keep the player and monsters inside. The player camera is limited to the same bounds.

## Weapons

Weapons search for the nearest enemy within their targeting range, rotate toward it, and attack at a stat-driven rate. The player has two weapon slots. The current authored weapons are Pistol, Machine Gun, and Shotgun, and all three fire projectiles through the [[Combat System]].

## Active skills

[[Active Skills]] have an early playable foundation. The player chooses two starter skills after choosing a starter weapon, then can use those skills during the wave. The first implemented skills are Bulletstorm Volley, Dash, and Frost Nova.

## Direction

The core action should support builds shaped by items, modifiers, and optional content. Encounter systems should add meaningful decisions without obscuring the readable movement-and-shooting foundation.
