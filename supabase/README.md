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
