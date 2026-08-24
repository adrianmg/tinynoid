---
version: 1
slug: "godot-scenes-community-lab-tscn"
primary_target: "godot/scenes/community_lab.tscn"
related_targets: ["godot/scripts/community_lab.gd","godot/scripts/community_catalog.gd"]
---

## Scope and mode

`godot/scenes/community_lab.tscn`. Operate mode inside the Neon Cartridge world.

## Audience, job, and action

A player should scan creator-attributed community cartridges, understand their
review state, verify one online, and begin unranked play with the usual controls.

## Content and constraints

- Each row reads `LEVEL NAME — BY CREATOR`.
- Pending records carry the magenta `UNREVIEWED` label; listed records say
  `LISTED`.
- Loading, empty, live, cached-offline, verification, and failure states are
  explicit.
- Cached rows are informational until an exact online lookup confirms they
  remain pending or listed.
- Keyboard, controller, and mouse share the same focus and selection model.
- Escape and a visible return row lead back to the main menu.
- The 256x240 canvas, bitmap font, hard rails, and opaque palette remain fixed.

## Chosen direction and memorable moment

The chooser is a compact cartridge rack inside the arena. Selection energizes
one cyan-edged row; its moderation stamp remains spatially attached so
`UNREVIEWED` cannot be mistaken for a global screen status.

## Unresolved decisions

Pagination and richer moderation metadata wait for catalog growth.
