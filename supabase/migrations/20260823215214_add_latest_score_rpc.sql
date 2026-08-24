create function public.get_latest_score()
returns table(
  player_name text,
  score integer,
  outcome text,
  completed_stage smallint,
  submitted_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    entry.player_name,
    entry.score,
    entry.outcome,
    entry.completed_stage,
    entry.submitted_at
  from public.scores as entry
  order by entry.submitted_at desc, entry.id desc
  limit 1;
$$;

revoke execute on function public.get_latest_score()
  from public, anon, authenticated;
grant execute on function public.get_latest_score()
  to anon, authenticated;
