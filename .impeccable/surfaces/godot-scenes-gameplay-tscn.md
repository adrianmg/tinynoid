---
version: 1
slug: "godot-scenes-gameplay-tscn"
primary_target: "godot/scenes/gameplay.tscn"
related_targets: ["godot/scenes/game_over.tscn","godot/scenes/stage_clear.tscn"]
---

## Scope and mode

`godot/scenes/gameplay.tscn` and its terminal states. Experience mode.

## Audience, job, and action

A developer or playtester should understand the state instantly, launch without
setup, clear the original rainbow-gate formation, and replay with the same FIRE
action on touch, keyboard, mouse, or controller.

## Content and constraints

- Native 256x240 canvas with integer scaling.
- Original procedural graphics and audio only.
- Score, stage, balls, launch readiness, stage clear, and game over are visible.
- 33 original layouts progress through eight motif families.
- Protected random drops select Expand, Slow, Disruption, Catch, Laser, Thru,
  Break, or Player within a density-based 2-8 capsule budget.
- The first stage reward arrives within 3-6 eligible brick breaks; later drops
  use a two-break cooldown and a ten-break pity limit.
- Score colors follow the documented 50–120 table; Silver scales by stage and
  Gold is indestructible without blocking clear.
- Every brick contact uses bounded generated pitch variation with no immediate
  repetition.
- Surviving Silver contacts flash white and use a sharper high-pitch waveform.
- Gold contacts use a low double-clunk to communicate indestructibility.
- Expand, Slow, Disruption, Catch, Laser, and Thru stack until life loss or stage
  clear; Break and Player are immediate.
- Life loss re-serves in place, preserving destroyed bricks, Silver damage, and
  score while resetting temporary effects and falling chips.
- Stage progression preserves score and remaining lives.
- Primary touch positions and drags the paddle; tap launches, fires Laser, and
  advances result screens without hiding keyboard, mouse, or controller input.
- Distinct deterministic pulse/arpeggio/bass/noise arrangements are generated
  for all 33 stages, persist across life loss, and are controlled by Sound.
- No ROM data, extracted assets, or copied level layouts.
- Community layouts reuse the native brick spawn rules but are always unranked.
- Community play keeps the standard Score, Stage, and Ball HUD columns. Stage
  shows the level name with a generated avatar and `@creator` beneath it.

## Chosen direction and memorable moment

The Neon Cartridge: ink-black arena, segmented ice-blue machine rails, compact
bitmap HUD, and a full-palette rainbow gate. The signature moment is a brick
shattering into opaque same-hue pixel shards while the ball leaves stepped cyan
afterimages. Falling chips announce their full mechanic name when collected.
Community cartridges adapt the Stage column persistently without adding an
overlay between the HUD and arena.

## Unresolved decisions

Pause and save data are outside this prototype.
