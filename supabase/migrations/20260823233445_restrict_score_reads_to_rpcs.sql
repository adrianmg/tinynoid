drop policy if exists "public leaderboard read" on public.scores;
revoke select on public.scores from anon, authenticated;
alter function public.get_top_scores(integer) security definer;
alter function public.get_latest_score() security definer;
