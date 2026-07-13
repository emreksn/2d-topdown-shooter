# Core Gameplay

> [!info] Status
> Partially implemented.

## Current loop

1. Choose a starter [[Weapon System|weapon]] at run start.
2. Prepare for the wave.
3. Fight while timed enemy spawning is active.
4. Clear remaining required enemies after spawning ends.
5. Auto-collect remaining drops.
6. Evaluate dropped items and [[Relics]].
7. Resolve queued [[Level Ups]].
8. Use the shop.
9. Select optional [[Content]] for the next wave.
10. Begin the next preparation phase.

The current build repeats the final configured wave definition, allowing the run to continue indefinitely.

## Player

The player has stat-driven movement speed and health. Death reloads the scene. Movement uses a shader-based squash effect for visual feedback.

The player HUD displays numeric current/maximum health, total gold, level, and experience progress toward the next level.

Defeated monsters drop separate gold and experience pickups. Pickups move toward the player inside the player's Pickup Range, while Instant Pickup Chance can award either reward immediately.

## Arena

The current arena is a bounded 1600×1000 playfield. A bright cyan border communicates its edges, and collision walls keep the player and monsters inside. The player camera is limited to the same bounds.

## Weapons

Weapons search for the nearest enemy within their targeting range, rotate toward it, and attack at a stat-driven rate. The player has two weapon slots. The current authored weapons are Pistol, Machine Gun, and Shotgun, and all three fire projectiles through the [[Combat System]].

## Active skills

[[Active Skills]] have an early playable foundation. The player can equip at most two Active Skills for use during a wave. The first implemented skills are Bulletstorm Volley and Dash.

## Direction

The core action should support builds shaped by items, modifiers, and optional content. Encounter systems should add meaningful decisions without obscuring the readable movement-and-shooting foundation.
