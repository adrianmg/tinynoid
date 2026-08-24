create table if not exists private.score_run_tickets (
  run_id uuid primary key,
  token_hash text not null,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz
);

create table if not exists private.stage_score_limits (
  completed_stage smallint primary key,
  max_score integer not null
);

alter table private.score_run_tickets enable row level security;
alter table private.stage_score_limits enable row level security;

insert into private.stage_score_limits (completed_stage, max_score)
values
  (1, 6450),
  (2, 10820),
  (3, 13780),
  (4, 16220),
  (5, 23070),
  (6, 27350),
  (7, 31200),
  (8, 36480),
  (9, 38320),
  (10, 44720),
  (11, 49410),
  (12, 52810),
  (13, 61280),
  (14, 68740),
  (15, 74120),
  (16, 79510),
  (17, 82600),
  (18, 92270),
  (19, 95910),
  (20, 102260),
  (21, 112040),
  (22, 119930),
  (23, 131530),
  (24, 140190),
  (25, 142380),
  (26, 152240),
  (27, 158560),
  (28, 163900),
  (29, 176360),
  (30, 187270),
  (31, 196200),
  (32, 206570),
  (33, 212690)
on conflict (completed_stage) do update
set max_score = excluded.max_score;

alter table public.scores
  drop constraint scores_score_range,
  add constraint scores_score_range check (score between 0 and 212690);

create or replace function public.issue_score_run(
  p_run_id uuid,
  p_token_hash text
)
returns table(expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  expiry timestamptz := clock_timestamp() + interval '6 hours';
begin
  if p_run_id is null then
    raise exception 'run_id is required' using errcode = '22023';
  end if;
  if p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'run token must be a SHA-256 digest'
      using errcode = '22023';
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
    clock_timestamp(),
    expiry,
    null
  )
  on conflict (run_id) do update
  set
    token_hash = excluded.token_hash,
    issued_at = excluded.issued_at,
    expires_at = excluded.expires_at
  where private.score_run_tickets.consumed_at is null;

  return query
  select ticket.expires_at
  from private.score_run_tickets as ticket
  where ticket.run_id = p_run_id
    and ticket.token_hash = p_token_hash
    and ticket.consumed_at is null;
end;
$$;

drop function if exists public.consume_score_rate_limit(
  text,
  integer,
  integer
);
drop function public.submit_score(
  uuid,
  text,
  integer,
  text,
  integer,
  integer
);

create function public.submit_score(
  p_run_id uuid,
  p_run_token_hash text,
  p_rate_key text,
  p_player_name text,
  p_score integer,
  p_outcome text,
  p_completed_stage integer,
  p_start_stage integer
)
returns table(score_id bigint, created boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_name text := upper(btrim(p_player_name));
  moderation_name text;
  existing_id bigint;
  stage_max_score integer;
  charged_count integer;
  request_time timestamptz := clock_timestamp();
  ticket_hash text;
  ticket_expires_at timestamptz;
  ticket_consumed_at timestamptz;
begin
  select score.id into existing_id
  from public.scores as score
  where score.run_id = p_run_id;
  if existing_id is not null then
    return query select existing_id, false;
    return;
  end if;

  if p_run_id is null then
    raise exception 'run_id is required' using errcode = '22023';
  end if;
  if p_run_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'run token is invalid' using errcode = '22023';
  end if;
  if p_rate_key !~ '^[0-9a-f]{64}$' then
    raise exception 'rate-limit key is invalid' using errcode = '22023';
  end if;

  select
    ticket.token_hash,
    ticket.expires_at,
    ticket.consumed_at
  into
    ticket_hash,
    ticket_expires_at,
    ticket_consumed_at
  from private.score_run_tickets as ticket
  where ticket.run_id = p_run_id
  for update;

  select score.id into existing_id
  from public.scores as score
  where score.run_id = p_run_id;
  if existing_id is not null then
    return query select existing_id, false;
    return;
  end if;

  if (
    ticket_hash is null
    or ticket_hash <> p_run_token_hash
    or ticket_consumed_at is not null
    or ticket_expires_at <= request_time
  ) then
    raise exception 'run ticket is missing, invalid, expired, or already used'
      using errcode = '22023';
  end if;

  if char_length(normalized_name) not between 1 and 16 then
    raise exception 'player_name must contain 1 to 16 characters'
      using errcode = '22023';
  end if;
  if normalized_name !~ '^@[A-Z0-9_]{1,15}$' then
    raise exception 'player_name must be an X handle'
      using errcode = '22023';
  end if;

  moderation_name := translate(
    regexp_replace(normalized_name, '[^A-Z0-9]', '', 'g'),
    '013457',
    'OIEAST'
  );
  if exists (
    select 1
    from private.blocked_player_name_terms as blocked
    where position(blocked.term in moderation_name) > 0
  ) then
    raise exception 'player_name is not allowed' using errcode = '22023';
  end if;

  if p_outcome not in ('game_over', 'campaign_clear') then
    raise exception 'outcome is invalid' using errcode = '22023';
  end if;
  if p_completed_stage not between 1 and 33 then
    raise exception 'completed_stage must be between 1 and 33'
      using errcode = '22023';
  end if;
  if p_outcome = 'campaign_clear' and p_completed_stage <> 33 then
    raise exception 'campaign_clear requires completed_stage 33'
      using errcode = '22023';
  end if;
  if p_start_stage <> 1 then
    raise exception 'only Stage 1 runs are eligible'
      using errcode = '22023';
  end if;

  select limits.max_score into stage_max_score
  from private.stage_score_limits as limits
  where limits.completed_stage = p_completed_stage;
  if p_score < 0 or p_score > stage_max_score then
    raise exception 'score is outside the completed-stage range'
      using errcode = '22023';
  end if;

  insert into private.score_submission_limits as limits (
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
    or limits.attempt_count < 5
  returning attempt_count into charged_count;

  if charged_count is null then
    raise exception 'score_rate_limit_exceeded' using errcode = 'P0001';
  end if;

  insert into public.scores (
    run_id,
    player_name,
    score,
    outcome,
    completed_stage,
    start_stage
  )
  values (
    p_run_id,
    normalized_name,
    p_score,
    p_outcome,
    p_completed_stage,
    p_start_stage
  )
  returning id into existing_id;

  update private.score_run_tickets
  set consumed_at = request_time
  where run_id = p_run_id;

  return query select existing_id, true;
end;
$$;

revoke execute on function public.issue_score_run(uuid, text)
  from public, anon, authenticated;
revoke execute on function public.submit_score(
  uuid,
  text,
  text,
  text,
  integer,
  text,
  integer,
  integer
) from public, anon, authenticated;

grant execute on function public.issue_score_run(uuid, text)
  to service_role;
grant execute on function public.submit_score(
  uuid,
  text,
  text,
  text,
  integer,
  text,
  integer,
  integer
) to service_role;
