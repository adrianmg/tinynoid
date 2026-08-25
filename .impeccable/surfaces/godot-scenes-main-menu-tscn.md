---
version: 1
slug: "godot-scenes-main-menu-tscn"
primary_target: "godot/scenes/main_menu.tscn"
related_targets: ["godot/scripts/display_controller.gd"]
---

## Scope and mode

`godot/scenes/main_menu.tscn`. Operate mode inside the Neon Cartridge world.

## Audience, job, and action

A playtester should start the stage or adjust window and sound settings in a
few seconds using touch, mouse, keyboard, or controller.

## Content and constraints

- Play, Community Lab, High Scores, Window mode, and four Sound levels (`III`,
  `II`, `I`, `OFF`) are the menu options.
- Left/Right changes the selected starting stage from 1 through 33.
- F2 selects 2x, F3 selects 3x, and F11 or Alt+Enter toggles fullscreen.
- Escape returns here from gameplay and quits when this menu is already active.
- Copy names logical actions rather than privileging a single device.
- The 256x240 pixel grid and opaque fixed palette remain normative.
- Focus movement and option activation use distinct generated chiptune sounds.
- Tapping an option selects and activates it in one deliberate press.
- The menu theme is a mysterious, dreamy 88 BPM space overture with sparse
  melody, fifth shimmer, and alternating-bar percussion.
- The subtitle reads `A TINY ARKANOID TRIBUTE BY @ADRIANMG`.
- A live line below the option panel shows the latest global player and score,
  with clear loading, empty, and offline states.
- Verified community deep links adapt the subtitle, preselect `PLAY SHARED LEVEL`,
  and identify the level and creator before gameplay begins.
- Desktop instructions cover arrow keys, Enter/Space, and Escape. On phones and
  tablets they switch to tap, drag, launch/fire, and swipe guidance.

## Chosen direction and memorable moment

The menu behaves like a cartridge boot screen inside the same segmented arena.
A cyan-edged focus band moves between terse bitmap options while the global
display shortcuts remain printed below the panel. Community Lab opens a
dedicated cartridge-style chooser rather than overloading campaign stage
selection.

## Unresolved decisions

Player identity is captured contextually after a terminal score rather than
before play. Additional settings and remapping controls remain outside this
prototype.
