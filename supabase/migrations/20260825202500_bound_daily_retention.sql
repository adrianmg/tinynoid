create function private.cleanup_daily_retention()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_time timestamptz := clock_timestamp();
begin
  delete from private.daily_run_tickets as ticket
  where ticket.expires_at <= request_time - interval '1 day'
    or (
      ticket.consumed_at is not null
      and ticket.consumed_at <= request_time - interval '1 hour'
    );
  delete from private.score_ticket_limits as limits
  where limits.window_started_at <= request_time - interval '2 hours';
  delete from private.score_submission_limits as limits
  where limits.window_started_at <= request_time - interval '2 hours';
  return null;
end;
$$;

revoke all on function private.cleanup_daily_retention()
  from public, anon, authenticated;

create trigger daily_run_ticket_retention
before insert on private.daily_run_tickets
for each statement execute function private.cleanup_daily_retention();
