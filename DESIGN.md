---
name: TINYNOID
description: A fixed-palette cartridge-era visual system for an original paddle-breaker.
colors:
  cartridge-void: "#050611"
  panel-ink: "#111329"
  rail-shadow: "#12345b"
  rail-blue: "#287fc4"
  ice-cyan: "#74ddff"
  phosphor-white: "#f7f4ff"
  score-yellow: "#ffd84a"
  brick-red: "#f15b68"
  brick-orange: "#ff8a3d"
  brick-green: "#56d46f"
  brick-blue: "#6d83f2"
  brick-magenta: "#c967e8"
typography:
  display:
    fontFamily: "TINYNOID 3x5 bitmap glyphs"
    fontSize: "10px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "2px"
  label:
    fontFamily: "TINYNOID 3x5 bitmap glyphs"
    fontSize: "5px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "1px"
rounded:
  none: "0px"
spacing:
  pixel: "1px"
  cell: "8px"
  rail: "16px"
components:
  result-panel:
    backgroundColor: "{colors.panel-ink}"
    textColor: "{colors.phosphor-white}"
    rounded: "{rounded.none}"
    padding: "20px"
  brick:
    backgroundColor: "{colors.brick-red}"
    rounded: "{rounded.none}"
    height: "8px"
    width: "14px"
---

# Design System: TINYNOID

## Overview

**Creative North Star: "The Neon Cartridge"**

TINYNOID looks as if its entire world were authored inside a constrained
console cartridge: every mark lands on the pixel grid, every color has a named
role, and depth comes from deliberate one-pixel bands rather than modern
effects. The playfield is the primary surface; interface chrome stays compact
and behaves like part of the game hardware.

The identity is energetic without becoming noisy. Black space creates tension,
ice-blue rails establish the machine, and a full brick palette carries the
stage. Result states reuse the same arena rather than switching to generic UI.

**Key Characteristics:**

- Native 256x240 composition with integer-only scaling.
- Hand-authored 3x5 bitmap lettering.
- Opaque fixed-palette colors; no smooth alpha transitions.
- Hard-edged geometry and one-pixel highlight/shadow bands.
- Dense gameplay framed by generous cartridge-black negative space.

## Colors

The palette pairs a near-black console field with an ice-blue machine frame and
a seven-hue brick spectrum.

### Primary

- **Cartridge Void** (`#050611`): The playfield and terminal-state background.
- **Ice Cyan** (`#74ddff`): Rails, mastheads, launch cues, and active guidance.
- **Rail Blue** (`#287fc4`): Structural midtone and lower panel rules.

### Secondary

- **Score Yellow** (`#ffd84a`): Scores, remaining balls, and high-value data.
- **Brick Red** (`#f15b68`), **Brick Orange** (`#ff8a3d`), **Brick Green**
  (`#56d46f`), **Brick Blue** (`#6d83f2`), and **Brick Magenta**
  (`#c967e8`): Stage identity and destruction feedback.

### Neutral

- **Panel Ink** (`#111329`): Result panels and brick outlines.
- **Phosphor White** (`#f7f4ff`): Ball, paddle face, labels, and flash frames.
- **Rail Shadow** (`#12345b`): Rail recesses and the final afterimage step.

**The Opaque Palette Rule.** Gameplay effects move through named colors in
discrete steps; they never dissolve through continuous alpha fades.

## Typography

**Display Font:** TINYNOID 3x5 bitmap glyphs
**Body Font:** TINYNOID 3x5 bitmap glyphs
**Label Font:** TINYNOID 3x5 bitmap glyphs

**Character:** A tiny all-caps console alphabet drawn by code. It favors brief
state labels, scores, and action prompts over prose.

### Hierarchy

- **Display** (2x pixel scale, 10px high): `GAME OVER` and `STAGE CLEAR`.
- **Title** (1x pixel scale, 5px high): `TINYNOID`.
- **Label** (1x pixel scale, 5px high): HUD headings and action prompts.
- **Data** (1x pixel scale, 5px high): zero-padded scores, stage, and ball count.

**The Cartridge Copy Rule.** Keep visible text uppercase and action-oriented;
instructions name the logical action (`FIRE`), not one device-specific key.

## Layout

The logical canvas is 256x240. The HUD owns the top 24 pixels. Segmented rails
begin at y=24 and frame an inner arena from x=16 to x=240. Bricks sit on a
16x10 placement rhythm, while their visible bodies are 14x8 to preserve a
one-pixel breathing channel. The paddle occupies the quiet lower quarter.

Scaling is always integer and aspect-preserving. Additional physical screen
space becomes black letterboxing rather than revealing more playfield.

## Elevation & Depth

There are no blur shadows. Depth is structural: one-pixel highlights sit on top
and left edges, saturated body color fills the center, and darker palette
partners define bottom and right edges. Panels separate through tonal blocks
and colored rules.

**The No Soft Light Rule.** Do not add glows, blur shadows, gradients, or
semi-transparent overlays. If an object needs depth, draw another hard pixel.

## Shapes

All corners are square. Rails are segmented, bricks are beveled rectangles,
stars are single pixels, and the ball is a stepped six-pixel disc. Curves are
represented through pixel stair-steps rather than antialiased geometry.

## Components

### Arena Rail

An eight-pixel structural band with a cyan leading edge, blue body, navy
recesses, and regular eight-pixel segmentation.

### Brick

A 14x8 black-outlined body with a 12x6 color core, one-pixel top highlight, and
one-pixel bottom/right shadow. White through Yellow use distinct score colors.
Silver shows one-pixel durability pips and darkens with damage; Gold carries a
white center bar and never breaks. Destruction emits opaque stepped shards in
the same hue. A surviving Silver hit flashes its core white for 80 ms and uses
a sharper, higher-pitched metallic contact voice. Gold responds with a low,
damped double-clunk that signals stubborn, permanent geometry.

### Paddle and Ball

The paddle is a 40x8 white face with cyan end caps and a steel bottom edge. The
ball is a compact white stepped disc with one cyan highlight pixel. Its trail is
a short sequence of integer-snapped 2x2 afterimages that remains completely
hidden while the ball is docked. The paddle collision shape is top-only so its
side cannot pinch the ball against an arena rail.

### Power-up Chip

A 12x8 falling chip with a black outline, saturated type color, one white edge,
and one dark edge. A centered bitmap glyph differentiates the eight mechanics:
`E` Expand, `S` Slow, `D` Disruption, `C` Catch, `L` Laser, `B` Break, `P`
Player, and `T` Thru. Collection repeats the full mechanic name above the
paddle. Thru adds a yellow spark cross to every active ball; it passes through
destructible bricks but still bounces off Gold. Expand, Slow, Disruption, Catch,
Laser, and Thru are compatible and accumulate for the current life. Break and
Player are immediate events rather than persistent states.
Laser collection expands the HUD label into
`LASER. SPACEBAR OR TAP TO FIRE` for three seconds.

Capsule timing uses protected randomness rather than marked bricks. The first
drop arrives on the third through sixth eligible destruction; later drops have
a two-brick cooldown and a rising pity chance that guarantees a drop by the
tenth eligible destruction. A density-based 2-8 capsule budget prevents sparse
stages from becoming reward floods. The first capsule of a new run is limited to
Expand, Slow, or Disruption, while later weighted choices avoid immediate
repeats and every effect that is already active.

### HUD

A single compact top strip: score on the left, stage centered, and balls on the
right. The product masthead is deliberately omitted during gameplay. The launch
cue reads `PRESS SPACEBAR OR TAP TO FIRE`, is centered at the bottom, and
disappears immediately after launch. A primary touch positions the paddle; a
drag steers it continuously; a tap launches held balls and fires Laser.

### Result Panel

A square ink panel floating inside the persistent arena frame. A colored top
rule names the outcome, a blue bottom rule anchors it, and `PRESS FIRE` exposes
the universal replay action.

### Main Menu

A compact ink panel inside the persistent arena frame. One cyan-edged selection
band identifies focus. Options expose Play, Window mode, and Sound; shortcuts
are printed below the panel. Help text names the keyboard and touch actions
while direct option taps require no hover state. Left and Right change the
starting stage from 1 through 33 when Play is selected.
Sound is rendered as `III`, `II`, `I`, or `OFF`, preserving the cartridge
language while communicating four discrete master-volume states. The title
subtitle reads `A TINY TRIBUTE FROM ADRIAN MATO TO ARKANOID`. Tapping an option
activates it directly. The lower region contains `ARROW KEYS TO MOVE & SELECT`,
`ENTER / SPACE / TAP TO SELECT`, and Escape instructions.
Moving focus produces a short descending pulse tick; activating an option uses
a brighter ascending two-note chirp. Both are generated, persistent across scene
changes, and follow the menu Sound setting.

### Soundtrack

The menu and every stage have a deterministic generated arrangement using two
pulse voices, triangle bass, and noise percussion. Stage changes alter tempo,
progression, scale, duty cycle, phrase rotation, bass turnaround, and drum grid.
Life re-serves keep the current stage track running; navigation and stage
changes are the musical transition points. The menu alone uses a calm, melodic
88 BPM space overture with an open minor progression, sparse two-bar melody,
quiet fifth shimmer, quarter-rate arpeggio, alternating-bar percussion, and an
octave lift.

## Do's and Don'ts

### Do:

- **Do** align positions, motion artifacts, and decorative marks to whole pixels.
- **Do** reuse the rail, starfield, and fixed palette across every state.
- **Do** reserve the TINYNOID masthead for menu and result screens.
- **Do** express feedback through color steps, frame swaps, and discrete motion.
- **Do** keep instructions device-neutral by naming mapped actions.

### Don't:

- **Don't** use copied ROM data, extracted game assets, or exact legacy layouts.
- **Don't** add gradients, glass, blur, antialiasing, or continuous alpha fades.
- **Don't** introduce rounded cards, stock fonts, or modern dashboard patterns.
- **Don't** let interface chrome compete with the playfield.
