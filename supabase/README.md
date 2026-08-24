# Supabase leaderboard

The `scores` table has no direct anonymous access. Two bounded read RPCs expose
only the latest entry or Top 100. Score writes pass through the public
`submit-score` Edge Function, which applies an IP rate limit before calling the
server-only database function.

The publishable key in the Godot client is public by design. Never add a
Supabase secret or service-role key to the repository.

A six-digit sanity cap, idempotent run IDs, and a network rate limit reject
casual forged or replayed submissions. They do not make gameplay
server-authoritative; the public leaderboard remains a best-effort arcade board.

## Moderation

Edit `private.blocked_player_name_terms` in the Supabase dashboard to extend
the name denylist. Remove an abusive score from the SQL editor:

```sql
delete from public.scores where run_id = '<run UUID>';
```
