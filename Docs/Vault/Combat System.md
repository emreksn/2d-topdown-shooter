# Combat System

> [!info] Status
> Implemented foundation.

Combat uses damage packets composed of one or more typed damage slices.

## Damage types

- Physical
- Lightning
- Cold
- Fire

Outgoing damage supports flat [[Weapon System|weapon]] damage, global actor modifiers, contextual tags, and damage conversion. Conversion keeps ancestry information so modifiers for original and converted damage types can remain applicable.

Incoming damage is reduced by type-specific resistance up to maximum resistance, then by Toughness. Monster Effectiveness also increases a monster's effective toughness.

## Current delivery methods

- Pistol projectiles.
- Enemy melee damage.

Damage numbers provide hit feedback. Health is managed by reusable health and hurtbox components.

## Damage display

A single hit displays a separate color-coded number for each damage type it deals. The largest component uses the normal display size. Smaller components scale down relative to the largest, and components below 2% of the largest are omitted to avoid visual noise.

Displayed typed amounts are normalized to the damage actually removed from health, so mitigation and overkill do not inflate the feedback.

## Related systems

- [[Stats and Modifiers]]
- [[Core Gameplay]]
- [[Weapon System]]
