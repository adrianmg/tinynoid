create index daily_cartridges_level_idx
  on private.daily_cartridges (level_id);
create index daily_run_tickets_daily_idx
  on private.daily_run_tickets (daily_id);
create index daily_run_tickets_level_idx
  on private.daily_run_tickets (level_id);
create index daily_scores_level_idx
  on public.daily_scores (level_id);
