create policy "deny direct score reads"
on public.scores
for select
to anon, authenticated
using (false);

revoke execute on function public.get_top_scores(integer)
  from anon, authenticated;
revoke execute on function public.get_latest_score()
  from anon, authenticated;
grant execute on function public.get_top_scores(integer)
  to service_role;
grant execute on function public.get_latest_score()
  to service_role;
