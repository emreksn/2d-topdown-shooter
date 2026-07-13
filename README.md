# 2D Topdown Shooter

A Godot 4 top-down shooter prototype with wave-based combat, weapons, item rewards, stat modifiers, and supporting design notes.

## Project

- Engine: Godot 4.7
- Main scene: `res://Scenes/UI/main_menu.tscn`
- Project file: `project.godot`

## Structure

- `Assets/` - source art and imported asset metadata
- `Data/` - Godot resources for items, stats, weapons, waves, and content variants
- `Scenes/` - gameplay, UI, enemy, weapon, reward, and feedback scenes
- `Scripts/` - game systems, components, combat, stats, UI, waves, and weapons
- `Shaders/` - shader resources
- `Tests/` - smoke and integration test scripts
- `Docs/Vault/` - Obsidian vault with design and systems documentation

## Getting Started

1. Open Godot.
2. Import this folder as a Godot project.
3. Open `project.godot`.
4. Run the project from the editor.

## Notes

The repository includes Godot `.import` and `.uid` metadata so references stay stable between machines. Local Godot editor state in `.godot/` is ignored.

The Obsidian vault is intentionally tracked under `Docs/Vault/`, but local workspace/cache files are ignored so routine editor layout changes do not create unnecessary Git updates.
