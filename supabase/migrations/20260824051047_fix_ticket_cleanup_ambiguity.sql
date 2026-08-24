create or replace function public.issue_score_run(
  p_run_id uuid,
  p_token_hash text,
  p_rate_key text
)
returns table(expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_time timestamptz := clock_timestamp();
  expiry timestamptz := request_time + interval '6 hours';
  charged_count integer;
  existing_consumed_at timestamptz;
  existing_expires_at timestamptz;
begin
  if p_run_id is null then
    raise exception 'run_id is required' using errcode = '22023';
  end if;
  if p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'run token must be a SHA-256 digest'
      using errcode = '22023';
  end if;
  if p_rate_key !~ '^[0-9a-f]{64}$' then
    raise exception 'rate-limit key is invalid' using errcode = '22023';
  end if;
  if exists (
    select 1
    from public.scores as score
    where score.run_id = p_run_id
  ) then
    raise exception 'run_id has already been submitted' using errcode = '22023';
  end if;

  delete from private.score_run_tickets as stale
  where stale.expires_at <= request_time
    or (
      stale.consumed_at is not null
      and stale.consumed_at <= request_time - interval '1 hour'
    );

  select ticket.consumed_at, ticket.expires_at
  into existing_consumed_at, existing_expires_at
  from private.score_run_tickets as ticket
  where ticket.run_id = p_run_id
  for update;

  if existing_consumed_at is null and existing_expires_at > request_time then
    update private.score_run_tickets
    set
      token_hash = p_token_hash,
      issued_at = request_time,
      expires_at = expiry
    where run_id = p_run_id;
    return query select expiry;
    return;
  end if;

  insert into private.score_ticket_limits as limits (
    key_hash,
    window_started_at,
    attempt_count
  )
  values (p_rate_key, request_time, 1)
  on conflict (key_hash) do update
  set
    window_started_at = case
      when limits.window_started_at <= request_time - interval '1 hour'
      then request_time
      else limits.window_started_at
    end,
    attempt_count = case
      when limits.window_started_at <= request_time - interval '1 hour'
      then 1
      else limits.attempt_count + 1
    end
  where
    limits.window_started_at <= request_time - interval '1 hour'
    or limits.attempt_count < 20
  returning attempt_count into charged_count;

  if charged_count is null then
    raise exception 'run_ticket_rate_limit_exceeded' using errcode = 'P0001';
  end if;

  insert into private.score_run_tickets (
    run_id,
    token_hash,
    issued_at,
    expires_at,
    consumed_at
  )
  values (
    p_run_id,
    p_token_hash,
    request_time,
    expiry,
    null
  )
  on conflict (run_id) do update
  set
    token_hash = excluded.token_hash,
    issued_at = excluded.issued_at,
    expires_at = excluded.expires_at,
    consumed_at = null;

  return query select expiry;
end;
$$;
