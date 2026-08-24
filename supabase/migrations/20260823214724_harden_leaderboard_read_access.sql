create policy "public leaderboard read"
on public.scores
for select
to anon, authenticated
using (true);

grant select (
  id,
  player_name,
  score,
  outcome,
  completed_stage,
  submitted_at
) on public.scores to anon, authenticated;

alter function public.get_top_scores(integer) security invoker;
revoke execute on function public.submit_score(
  uuid,
  text,
  integer,
  text,
  integer
) from authenticated;
