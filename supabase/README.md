# Supabase leaderboard

The `scores` table has no direct anonymous access. Two bounded read RPCs expose
only the latest entry or Top 100. Score writes pass through the public
`submit-score` Edge Function. Eligible Stage 1 runs first receive a six-hour,
one-time ticket from `start-run`.

The publishable key in the Godot client is public by design. Never add a
Supabase secret or service-role key to the repository.

The database locks and consumes each ticket atomically, validates the
completed-stage score ceiling, and charges the five-per-hour network quota only
for a first-created score. Same-run retries return the original result without
using more quota. This rejects casual forged or replayed submissions without
claiming fully server-authoritative gameplay.

## Moderation

Edit `private.blocked_player_name_terms` in the Supabase dashboard to extend
the name denylist. Remove an abusive score from the SQL editor:

```sql
delete from public.scores where run_id = '<run UUID>';
```

## Community levels

`submit-level` accepts canonical version 1 level documents and
`community-levels` returns the bounded public catalog. Both functions enforce
the production/loopback CORS allowlist and use the service role only inside the
Edge runtime. No community-level table or RPC is directly available to
`anon` or `authenticated`.

Level content is immutable. A normalized document hashes to a stable
`cl_<24 lowercase hex characters>` id; an exact resubmission returns that id
with `created: false`. Anonymous submission network identifiers are HMAC-SHA256
digests and are limited to five attempts per fixed one-hour window. Catalog
responses contain only the id, schema version, normalized names, layout,
populated count, creation timestamp, and public status. Quarantined and removed
levels are excluded.

### Moderation RPC

Only `service_role` may execute:

```sql
select *
from public.moderate_community_level(
  p_level_id := 'cl_<24 lowercase hex characters>',
  p_new_status := 'listed',
  p_actor := 'moderator@example.com',
  p_reason := 'Reviewed'
);
```

Supported transitions are:

- `pending` to `listed`, `quarantined`, or `removed`
- `listed` to `quarantined` or `removed`
- `quarantined` to `pending`, `listed`, or `removed`
- `removed` is terminal

A nonblank reason is required when quarantining or removing a level. Every
successful transition updates current state and appends an actor, reason, and
timestamp to `private.community_level_moderation_events`; content is never
updated.

## Local validation

From the repository root:

```sh
deno fmt --check supabase/functions/_shared \
  supabase/functions/submit-level supabase/functions/community-levels
deno check supabase/functions/submit-level/index.ts \
  supabase/functions/community-levels/index.ts
deno test supabase/functions

supabase start
supabase db reset
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  -v ON_ERROR_STOP=1 -f supabase/tests/community_levels.sql
```

Serve the public functions locally:

```sh
supabase functions serve submit-level --no-verify-jwt
supabase functions serve community-levels --no-verify-jwt
```

## Deployment

Apply migrations before deploying the functions. These commands do not run as
part of local validation:

```sh
supabase db push
supabase functions deploy submit-level --no-verify-jwt
supabase functions deploy community-levels --no-verify-jwt
```

Supabase supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to hosted Edge
Functions. Do not expose or add the service-role key to client configuration.
