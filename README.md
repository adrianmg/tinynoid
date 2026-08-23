# Pikonoid

[![CI](https://github.com/adrianmg/arkanoid/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/adrianmg/arkanoid/actions/workflows/ci.yml)
[![Release main](https://github.com/adrianmg/arkanoid/actions/workflows/release-main.yml/badge.svg?branch=main)](https://github.com/adrianmg/arkanoid/actions/workflows/release-main.yml)

An original, NES-era paddle-breaker prototype built in Godot 4.7.2.

**A tiny tribute by Adrian Mato**

The playable Godot project lives in [`godot/`](godot/). The Unity project remains
alongside it as migration history, but the Godot game does not use its sprites,
audio, generated Tiled data, or Unity-specific code.

## Run

Open `godot/project.godot` in Godot 4.7.2 and run the main scene.

Controls:

- Move: mouse, Left/Right, A/D, or controller stick
- Launch: Space, left mouse button, or controller face button
- Restart: R
- Return to menu: Escape during gameplay
- Quit: Escape from the main menu
- Window 2x: F2
- Window 3x: F3
- Toggle fullscreen: F11 or Alt+Enter

The main menu also exposes Play, Window mode, and four Sound levels with
keyboard, controller, and mouse navigation. With Play selected, Left/Right
chooses any starting stage from 1 through 33.

## Validate

Run the focused headless suite from the repository root:

```sh
godot --headless --path godot res://tests/test_runner.tscn
```

The checked-in Web export preset can also be validated without installing
platform templates:

```sh
godot --headless --path godot --export-pack Web /tmp/pikonoid.pck
```

## Automated releases

Every successful merge to `main` publishes a GitHub prerelease containing Web,
Windows x86_64, Linux x86_64, and macOS universal builds plus SHA-256
checksums and GitHub build-provenance attestations:

<https://github.com/adrianmg/arkanoid/releases>

The port deliberately keeps Godot defaults for physics rate, VSync, frame
limiting, solver settings, gravity, and audio. It overrides only settings tied
to the game: a 256x240 integer-scaled viewport, nearest-neighbor texture
filtering, a black background, the Compatibility renderer, inputs, and collision
layers.

Rendering is pixel-perfect: the game renders to a 256x240 logical viewport,
uses nearest filtering and integer scaling, and snaps 2D transforms to logical
pixels. Vertex snapping remains disabled to avoid double-snap movement jitter.

The current game has 33 original stages across eight motif families, a 200 px/s
ball, three balls per game, a pixel HUD, score tracking, procedural brick
effects and chiptune audio, campaign progression, Game Over, and instant replay.
It does not yet include pause or save data.

Seven marked bricks drop power-up chips:

- **E - Expand:** widens the paddle
- **S - Slow:** slows active balls
- **D - Disruption:** creates a three-ball split
- **C - Catch:** catches a returning ball for FIRE release
- **L - Laser:** equips paired paddle lasers
- **B - Break:** immediately advances to the next stage
- **P - Player:** adds one ball to the session counter

Expand, Slow, Disruption, Catch, and Laser are mutually exclusive temporary
effects. They last until another temporary chip is collected, the current life
ends, or the stage is cleared. Disruption remains active while more than one
split ball survives. Break and Player are immediate and do not replace the
current temporary effect before resolving. Every collected chip awards 100
points.

Losing a life resets the paddle, ball speed, active temporary effect, split
balls, and falling chips, then docks a new serve in the same gameplay scene.
Score, destroyed bricks, surviving bricks, and Silver damage are preserved.

Brick rules:

| Brick | Points | Hits |
| --- | ---: | ---: |
| White | 50 | 1 |
| Orange | 60 | 1 |
| Light Blue | 70 | 1 |
| Green | 80 | 1 |
| Red | 90 | 1 |
| Blue | 100 | 1 |
| Pink | 110 | 1 |
| Yellow | 120 | 1 |
| Silver | 50 × stage | 2–5 by stage band |
| Gold | 0 | Indestructible |

Every brick contact uses generated chiptune audio with bounded pitch variation;
consecutive hits never repeat the same pitch. Surviving Silver hits use a
distinct sharper metallic waveform in a higher pitch range and flash white for
80 ms. Gold contacts use a low, damped two-part metallic clunk that communicates
the brick will not break.

The soundtrack is generated entirely in code. The menu and each of the 33
stages receive a deterministic, distinct arrangement that varies tempo,
progression, scale, melody rotation, pulse duty, arpeggio direction, bass
turnaround, and drum grid. Every track uses pulse melody, pulse arpeggio,
triangle bass, and deterministic noise drums in signed 8-bit mono PCM at
22.05 kHz. Runtime playback is synthesized into a short streaming buffer, so
menu and first-time stage changes do not build an entire song before switching.
Reloading a life does not restart or reset the current stage song.

The menu arrangement is a mysterious, dreamy 88 BPM space overture with an open
A-E-G-D minor progression, a sparse two-bar melody, quiet fifth shimmer,
quarter-rate arpeggio, alternating-bar percussion, and an octave lift.

The menu's Sound option controls the full mix at **III (0 dB)**, **II (-6 dB)**,
**I (-12 dB)**, or **OFF**. Enter/FIRE cycles downward; Left/Right adjusts in
either direction. Menu movement uses a generated 45 ms pulse tick; activation
uses a generated two-note 130 ms confirmation chirp.

Paddle bounce direction is continuous across its full width: center hits return
nearly vertical, edge hits reach a bounded 68-degree angle, and paddle movement
adds a small amount of steering influence. The ball afterimage is disabled while
the ball is docked on the paddle. The paddle collider is top-only, so wall-edge
contacts cannot trap the ball between the paddle side and arena rail.

While docked, the HUD advises: **Press spacebar to fire the ball**.

All Godot-side presentation assets are generated by the project. No ROM data,
extracted graphics, sampled game audio, or copied level layouts are used.
