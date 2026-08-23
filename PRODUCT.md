# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

The primary user is a developer or playtester evaluating a compact Godot port
and tuning the feel of an arcade paddle-breaker on desktop or in a browser.

## Product Purpose

The prototype demonstrates a complete single-stage paddle-breaker loop:
launching and steering a paddle, clearing a patterned brick field, tracking
score and balls, reaching stage clear, losing a game, and replaying quickly.

## Positioning

This is a legally distinct, source-readable Godot prototype inspired by the
mechanical clarity of early console paddle-breakers. It does not use ROM data,
extracted assets, copied level data, or production branding from another game.

## Operating Context

The prototype is run locally from the Godot editor, as a desktop process, or as
a Web export. Playtesting uses mouse, keyboard, or a standard game controller.

## Capabilities and Constraints

- Godot 4.7.2 with GDScript and the Compatibility renderer.
- A 256x240 logical canvas with integer scaling.
- Main menu with Play, window scale/fullscreen, and four persistent sound levels.
- 33 original stages, selectable starts, progression, score, stage-clear,
  game-over, and replay.
- Eight falling capsule mechanics: Expand, Slow, Disruption, Catch, Laser,
  Break, Player, and Thru.
- Expand, Slow, Disruption, Catch, Laser, and Thru are mutually exclusive and
  reset on life loss or stage clear; Break and Player are immediate.
- Brick destruction and Silver damage persist when a life is lost.
- Continuous position-based paddle bounce with bounded motion influence.
- Eight one-hit score colors, stage-scaled Silver, and indestructible Gold.
- Durable Silver contacts use higher metallic audio and a white impact flash.
- Indestructible Gold contacts use a low double-clunk feedback voice.
- Original deterministic four-voice chiptune arrangements for the menu and all
  33 stages.
- Original generated menu movement and confirmation sound effects.
- All new presentation assets are procedural and original to this repository.
- No ROM downloads, asset extraction, or exact reproduction of copyrighted
  level layouts.
- The project is a non-commercial prototype, but that does not relax the
  original-content constraint.

## Brand Commitments

The game and project are named **TINYNOID**, subtitled
**A tiny tribute from Adrian Mato to Arkanoid**.
The experience should remain immediate, arcade-readable, and playful rather
than becoming a simulation or content-heavy campaign.

## Evidence on Hand

The repository contains a working Godot gameplay implementation and a legacy
Unity prototype. There are no licensed third-party brand assets, commercial
claims, user testimonials, or approved ROM-derived materials.

## Product Principles

- Preserve responsive arcade control over physical realism.
- Make every state legible within a second.
- Keep the full loop replayable without menus or setup.
- Prefer engine-native, inspectable implementation over opaque tooling.
- Use only original or clearly licensed presentation assets.

## Accessibility & Inclusion

Core actions must remain available through keyboard, mouse, and controller.
Gameplay information uses high-contrast color plus stable spatial placement;
rapid full-screen flashes are avoided.
