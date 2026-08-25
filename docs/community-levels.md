# Community levels

Community levels are immutable, unranked cartridges submitted from the static
editor at `/editor/`, stored in Supabase, and loaded by the Godot Community Lab.
The Edge Functions are the only public network seam. Browser and game clients
never receive a service-role credential and cannot write database tables
directly.

## Canonical schema v1

The machine-readable contract is
[`schema/community-level-v1.schema.json`](../schema/community-level-v1.schema.json).

```json
{
  "schema_version": 1,
  "level_name": "NEON RUN",
  "creator_display_name": "@BUILDER",
  "layout": [
    "RRRRRRRR.....",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    ".............",
    "............."
  ]
}
```

The layout is exactly 13 columns by 10 rows. Each row uses the native Godot
brick codes:

| Code | Cell |
| --- | --- |
| `.` | Empty |
| `W` | White |
| `O` | Orange |
| `C` | Cyan |
| `G` | Green |
| `R` | Red |
| `B` | Blue |
| `P` | Pink |
| `Y` | Yellow |
| `S` | Silver |
| `X` | Gold, indestructible |

Names are trimmed, internal whitespace is collapsed, and text is uppercased.
Level names are 2–32 characters and creator names are 2–24 characters. Both
accept only `A-Z`, `0-9`, spaces, `@`, `.`, `_`, and `-`.

A valid cartridge has at least eight destructible cells and no more than 100
populated cells. Requests are limited to 4096 bytes.

The canonical hash input is UTF-8 text with newline separators:

```text
1
LEVEL NAME
CREATOR
ROW 1
...
ROW 10
```

Its lowercase SHA-256 digest is the immutable content hash. Public identifiers
are `cl_` plus the first 24 hash characters. Re-submitting the same normalized
document returns the existing identifier with `created: false`.

## Public interfaces

All production calls use
`https://ugkygoijpqrreooylpnc.supabase.co/functions/v1`.
The publishable key may be sent in the `apikey` header; the service-role key
must remain only in Supabase function secrets.

- `POST /submit-level` validates, normalizes, rate-limits, hashes, and stores a
  cartridge. New records begin as `pending`.
- `GET /community-levels?limit=100` returns a bounded public catalog.
- `GET /community-levels?id=cl_…` confirms that one cached or deep-linked level
  is still publicly playable.
- `POST /rest/v1/rpc/get_community_level_share` resolves one playable level by
  immutable id or canonical friendly slug.
- `GET /share-level?id=cl_…` redirects legacy share URLs to Vercel.
- `GET /share-level?id=cl_…&image=1` renders a 1200x630 PNG from the immutable
  level name, creator, moderation label, and 13x10 layout.

Successful editor submissions expose a direct play URL and a personalized URL
such as `https://tinynoid.vercel.app/love-yah`. The oldest level with a
normalized name permanently owns the bare slug; later name collisions use
`love-yah-cl_<24 lowercase hex characters>`. Opening either route performs the
exact online freshness check, then presents the linked unranked level
preselected on the TINYNOID main menu. The editor uses the personalized route
for the platform share sheet and clipboard fallback.

Only `pending` and `listed` records are returned. `pending` means playable but
must be rendered as `UNREVIEWED`. `quarantined` and `removed` records are never
returned by either public lookup.

## Moderation contract

Content rows are immutable. Moderation state is stored separately and changed
through a service-role-only SQL RPC. The allowed states are:

- `pending`: immediately playable in the unranked Lab as `UNREVIEWED`
- `listed`: reviewed and publicly listed
- `quarantined`: hidden while review or remediation is required
- `removed`: hidden terminal state

The moderation call accepts a public level identifier, target state, actor, and
optional reason. It returns `level_id`, `previous_status`, `status`, `actor`,
`reason`, and `status_changed_at`. Anonymous and authenticated roles have no
execute grant.
Future automation should render the canonical `layout` itself, review that
thumbnail together with the normalized names, then invoke this RPC with its
service-role credential. No AI provider, model, or secret belongs in this
repository.

## Local workflow

Run the editor:

```sh
python3 -m http.server 4173 --directory web
```

Open <http://127.0.0.1:4173/editor/>. Localhost and `127.0.0.1` origins are
accepted by the Edge Functions; production CORS is restricted to
`https://tinynoid.vercel.app`.

Run focused tests:

```sh
node --test web/tests/*.test.mjs
deno test supabase/functions/_shared/*.test.ts
godot --headless --path godot res://tests/test_runner.tscn
```

## Supabase deployment

Apply committed migrations and deploy only the community functions:

```sh
supabase link --project-ref ugkygoijpqrreooylpnc
supabase db push
supabase functions deploy submit-level --project-ref ugkygoijpqrreooylpnc --no-verify-jwt
supabase functions deploy community-levels --project-ref ugkygoijpqrreooylpnc --no-verify-jwt
supabase functions deploy share-level --project-ref ugkygoijpqrreooylpnc --no-verify-jwt
```

After DDL changes, run Supabase security and performance advisors. Exercise
submission, duplicate submission, catalog visibility, moderation hiding, and
rate limiting against disposable rows, then remove those rows through a
service-role transaction.

Vercel runs `tinynoid-share/build.sh`, exports Godot, and places the editor,
schema, and OG assets beside the game under one production domain.
