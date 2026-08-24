---
version: 1
slug: "web-editor-index-html"
primary_target: "web/editor/index.html"
related_targets: ["web/editor/styles.css","web/editor/app.js"]
---

## Scope and mode

`web/editor/`. Operate mode inside the Neon Cartridge world.

## Audience, job, and action

Anyone on a phone or desktop should be able to label, paint, validate, and
submit an original fixed-grid phase without learning a separate design tool.

## Content and constraints

- The 13×10 matrix is the primary instrument and remains visible as a whole.
- Cells cycle through empty and every native TINYNOID brick code.
- Keyboard, pointer, and touch input expose the same authoring path.
- Level and creator names are required and normalized before submission.
- Density, validation, loading, error, duplicate, and success states are explicit.
- Submission uses only the public Edge Function and publishable key.
- Pending submissions are introduced as immediately playable, unranked, and
  `UNREVIEWED`.
- Desktop keeps the controls beside the arena; narrow layouts place them below.
- The visual system uses hard pixels, opaque palette colors, and square geometry.

## Chosen direction and memorable moment

The editor is a cartridge workbench rather than a dashboard. The live arena is
the largest object; cycling one cell immediately turns an empty socket into a
beveled game brick while the playability readout updates beside it.

## Unresolved decisions

Later moderation tooling may reuse the canonical renderer, but review controls
do not belong on this public authoring surface.
