# TINYNOID

🎮 A tiny tribute to the classic NES Arkanoid, built in Godot with a twist:
procedurally generated graphics and music.

## Play on any platform

[▶ Play TINYNOID in your browser](https://tinynoid.vercel.app/)

[🧱 Build a Community Lab level](https://tinynoid.vercel.app/editor/)

| Platform | Download |
| --- | --- |
| Web | [tinynoid-web.zip](https://github.com/adrianmg/tinynoid/releases/latest/download/tinynoid-web.zip) |
| Windows x86_64 | [tinynoid-windows-x86_64.zip](https://github.com/adrianmg/tinynoid/releases/latest/download/tinynoid-windows-x86_64.zip) |
| Linux x86_64 | [tinynoid-linux-x86_64.tar.gz](https://github.com/adrianmg/tinynoid/releases/latest/download/tinynoid-linux-x86_64.tar.gz) |
| macOS universal | [tinynoid-macos-universal.zip](https://github.com/adrianmg/tinynoid/releases/latest/download/tinynoid-macos-universal.zip) |
| Checksums | [SHA256SUMS](https://github.com/adrianmg/tinynoid/releases/latest/download/SHA256SUMS) |

## Screenshots

| Main menu | Stage 1 — Rainbow Gate | Stage 17 — Waveform II |
| --- | --- | --- |
| ![TINYNOID main menu](docs/screenshots/menu.png) | ![TINYNOID Stage 1](docs/screenshots/stage-01.png) | ![TINYNOID Stage 17](docs/screenshots/stage-17.png) |

## Play

Open [`godot/project.godot`](godot/project.godot) in Godot 4.7.2 and run the
main scene.

### Controls

- **Move:** Arrow keys, A/D, mouse, touch drag, or controller stick
- **Launch / Select:** Spacebar, Enter, click, tap, or controller face button
- **Menus / High Scores:** Arrow keys, click, tap, or controller
- **Restart stage:** R
- **Return to menu:** Escape
- **Window size:** F2 for 2×, F3 for 3×
- **Fullscreen:** F11 or Alt+Enter

## Highlights

- 33 original stages
- Eight capsules: Expand, Slow, Disruption, Catch, Laser, Break, Player, and Thru
- Compatible capsule effects stack together until life loss or stage clear
- Protected random drops reward the opening and prevent long dry streaks
- Global Top 100 scores with offline local history
- Post-game X/Twitter handles and deterministic pixel avatars
- Unranked Community Lab levels with creator attribution and moderation status
- Mobile-friendly fixed-grid community level editor
- Personalized share links with level-specific pixel-art previews
- Shareable Game Over and Campaign Clear score cards
- Standard, multi-hit Silver, and indestructible Gold bricks
- Pixel-perfect 256×240 rendering with integer scaling
- Distinct procedurally generated music for the menu and every stage
- Generated sound effects, visuals, animations, and level layouts

## Development

Run the headless test suite:

```sh
godot --headless --path godot res://tests/test_runner.tscn
node --test web/tests/*.test.mjs
deno test supabase/functions/_shared/*_test.ts
npm run build --prefix tinynoid-share
```

Serve the static level editor locally:

```sh
python3 -m http.server 4173 --directory web
```

Then open <http://127.0.0.1:4173/editor/>. Community levels and their secure
Supabase deployment contract are documented in
[`docs/community-levels.md`](docs/community-levels.md).

## Deployment

Vercel hosts the complete production app at
[tinynoid.vercel.app](https://tinynoid.vercel.app/). The connected Vercel
project uses `tinynoid-share/` as its root and deploys `main` automatically.
Its build exports Godot Web and places the editor, schema, social cards, and
friendly community-level pages under the same domain.
The Vercel project setting **Include files outside the Root Directory in the
Build Step** must remain enabled because the build reads `godot/`, `web/`,
`schema/`, and `.github/scripts/`.

Supabase remains the leaderboard, community catalog, moderation, and dynamic
level-preview backend. Friendly level slugs are resolved by a database RPC so
published links remain stable as the catalog grows.

The legacy Unity project remains in the repository as migration history. The
Godot game uses original layouts and generated presentation assets.
