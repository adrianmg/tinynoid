---
version: 1
slug: "godot-scenes-high-scores-tscn"
primary_target: "godot/scenes/high_scores.tscn"
related_targets: ["godot/scenes/name_entry.tscn", "godot/scenes/game_over.tscn", "godot/scenes/stage_clear.tscn"]
---

## Scope and mode

Leaderboard and player-identity screens in Operate mode inside the established
Neon Cartridge world.

## Audience, job, and action

Players inspect the global Top 100, identify their own local results while
offline, enter a reusable player name, and share a terminal score without
leaving the controller-first game flow.

## Content and constraints

- Fourteen leaderboard rows fit at once on the 256x240 canvas.
- Up/Down moves one row, Left/Right moves one page, and the mouse wheel scrolls.
- The first terminal score asks for an X/Twitter handle; `@` is shown and
  stored implicitly rather than entered as a character.
- Handles use X-compatible `A-Z`, `0-9`, and `_`, with a visible glyph picker.
- Loading, empty, cached-offline, local-only, and error states remain explicit.
- A centered, selectable `RETURN TO MENU` footer matches Community Lab instead
  of duplicating a separate top-right Back control.
- Avatars are deterministic palette pixels generated locally from each handle;
  leaderboard rendering never depends on remote profile photography.
- Terminal results expose one `SHARE ON TWITTER` action. Web builds hand its
  generated PNG to the platform share sheet and retain an X intent fallback.

## Chosen direction and memorable moment

The leaderboard reads like a live cartridge attract screen: dense ranked rows,
tiny generated player faces, fixed data columns, and one cyan selection rail.

## Unresolved decisions

Verified social identities and direct X media posting remain intentionally out
of scope.
