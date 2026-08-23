# Pikonoid

A tiny tribute from me to the original game.

Pikonoid is an original, pixel-perfect paddle-breaker built with Godot 4.7.2.
Clear 33 stages, collect seven power capsules, and chase a high score through
procedural visuals, effects, and chiptune music.

## Screenshots

| Main menu | Stage 1 — Rainbow Gate | Stage 17 — Waveform II |
| --- | --- | --- |
| ![Pikonoid main menu](docs/screenshots/menu.png) | ![Pikonoid Stage 1](docs/screenshots/stage-01.png) | ![Pikonoid Stage 17](docs/screenshots/stage-17.png) |

## Play

Open [`godot/project.godot`](godot/project.godot) in Godot 4.7.2 and run the
main scene.

### Controls

- **Move:** Arrow keys, A/D, mouse, or controller stick
- **Launch / Select:** Spacebar, Enter, mouse button, or controller face button
- **Restart stage:** R
- **Return to menu:** Escape
- **Window size:** F2 for 2×, F3 for 3×
- **Fullscreen:** F11 or Alt+Enter

## Highlights

- 33 original stages
- Seven capsules: Expand, Slow, Disruption, Catch, Laser, Break, and Player
- Standard, multi-hit Silver, and indestructible Gold bricks
- Pixel-perfect 256×240 rendering with integer scaling
- Distinct procedurally generated music for the menu and every stage
- Generated sound effects, visuals, animations, and level layouts

## Development

Run the headless test suite:

```sh
godot --headless --path godot res://tests/test_runner.tscn
```

The legacy Unity project remains in the repository as migration history. The
Godot game uses original layouts and generated presentation assets.
