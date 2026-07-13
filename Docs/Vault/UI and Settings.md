# UI and Settings

> [!info] Status
> Implemented foundation.

The game uses a 1920x1080 canonical viewport with `canvas_items` stretch mode and `expand` aspect. UI should scale up or down from that baseline without changing gameplay camera zoom.

## Display settings

Display and interface preferences are persisted in `user://settings.cfg` through the `GameSettings` autoload.

Current saved settings:

- Window mode: Windowed, Borderless Fullscreen, or Exclusive Fullscreen.
- Monitor index, clamped to a valid monitor at startup.
- Resolution: 1280x720, 1600x900, 1920x1080, or 2560x1440.
- VSync enabled or disabled.
- FPS cap: Off, 60, 120, or 144.
- UI scale: 75%, 100%, 125%, or 150%.

Normal windowed mode is the default for stable editor and multi-monitor testing. Borderless Fullscreen and Exclusive Fullscreen remain available through Options.

Display application uses a strict single-monitor sequence:

1. Apply runtime settings such as VSync and FPS cap.
2. Clamp the saved monitor to a valid display.
3. Reset the game window to normal windowed mode.
4. Assign the window to the target monitor.
5. Move and size the window fully inside that monitor.
6. Enter the requested window mode.

Exclusive Fullscreen uses Godot's exclusive fullscreen window mode. No manual size or position changes are made after entering exclusive fullscreen. Borderless Fullscreen remains windowed, borderless, and is sized and positioned exactly to the selected monitor's bounds.

## Main menu

Pressing Play immediately disables the menu buttons, changes the Play label to `LOADING...`, and shows a loading overlay before changing to the game scene. This prevents the launch flow from feeling unresponsive during scene initialization.

Options are available from the main menu. In-game options are not part of the current implementation.

## Pause menu

Pressing Escape opens the in-game pause menu. The pause menu pauses the scene tree only when it owns the pause, so it does not unpause other systems that paused the game for their own modal UI.

The pause menu includes a Stats screen that shows:

- Player stats.
- Current weapon stats.
- Base value and current resolved value.
- A Modified only toggle.

Current values are color-coded against base values:

- Green means the resolved value is higher than base.
- Red means the resolved value is lower than base.
- Neutral gray means unchanged.

## Responsive UI

Post-wave UI panels should use shared presentation helpers for:

- Rarity colors.
- Button and panel styleboxes.
- Standard margins.
- Centered panels clamped to the visible viewport.

Long or variable content should use scroll containers instead of shrinking controls until text becomes unreadable. This applies especially to shop inventory, item evaluation text, level-up choices, and Content choice modifier text.

## UI layer order

Current overlay layer order:

- Shop and inventory: `20`.
- Content choice: `28`.
- Level-up choices: `30`.
- Item evaluation: `31`.
- Starter weapon choice: `32`.
- Monster inspect tooltip: `90`.
- Pause menu: `100`.

Loading and Options overlays live on the main menu scene itself and are not part of the in-game overlay layer stack.
