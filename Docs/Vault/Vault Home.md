# Vault Home

This vault is the living source of truth for the game. Feature work should be checked against these notes, and the relevant notes should be updated when implementation or design changes.

## Game foundation

- [[Game Overview]]
- [[Core Gameplay]]
- [[Wave System]]
- [[Combat System]]
- [[Weapon System]]
- [[Stats and Modifiers]]
- [[UI and Settings]]
- [[Active Skills]]
- [[Items]]
- [[Level Ups]]
- [[Relics]]

## Content mechanics

- [[Content]]
- [[Rift]]
- [[Ancient Ritual]]
- [[Boss Encounter]]
- [[Hellforge Gauntlet]]
- [[The Tower]]

## Hellforge

- [[Hellforge Gauntlet]]
- [[Hellmaster]]
- [[Hellforge]]
- [[Hellforged]]
- [[Hellforged Modifier]]

## Documentation rules

- Treat explicit design statements as intended game behavior.
- Keep planned concepts distinct from implemented features.
- Update linked notes when code changes their behavior.
- Mark unresolved details as open questions rather than silently inventing canon.
- Prefer one focused note per feature and connect related concepts with Obsidian links.

## Resolving open questions

Open questions are prompts, not requirements. They identify design details that have not been established yet.

To answer one, write the decision directly below it:

```md
- How many floors does a Tower contain?
  - **Decision:** A standard Tower contains 10 floors.
```

Once a decision is firm, move it into the main design section and remove it from **Open questions**. If the answer is tentative, label it **Draft** instead of **Decision**.
