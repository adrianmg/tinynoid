create table private.score_run_tickets (
  run_id uuid primary key,
  token_hash text not null,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz
);

create table private.stage_score_limits (
  completed_stage smallint primary key,
  max_score integer not null
);

insert into private.stage_score_limits (completed_stage, max_score)
values
  (1, 6350),
  (2, 10820),
  (3, 14080),
  (4, 16920),
  (5, 23670),
  (6, 28150),
  (7, 32300),
  (8, 37780),
  (9, 40120),
  (10, 46520),
  (11, 51410),
  (12, 55210),
  (13, 63580),
  (14, 71040),
  (15, 76620),
  (16, 82110),
  (17, 85600),
  (18, 95170),
  (19, 99110),
  (20, 105760),
  (21, 115440),
  (22, 123530),
  (23, 135030),
  (24, 143890),
  (25, 146480),
  (26, 156240),
  (27, 162760),
  (28, 168500),
  (29, 180860),
  (30, 191770),
  (31, 200600),
  (32, 210870),
  (33, 217290);

create function public.issue_score_run(
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
  if char_length(p_token_hash) <> 64 then
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
  inserted_id bigint;
  stage_max_score integer;
begin
  select existing.id into inserted_id
  from public.scores as existing
  where existing.run_id = p_run_id;
  if inserted_id is not null then
    return query select inserted_id, false;
    return;
  end if;

  if p_run_id is null then
    raise exception 'run_id is required' using errcode = '22023';
  end if;
  if char_length(p_run_token_hash) <> 64 then
    raise exception 'run token is invalid' using errcode = '22023';
  end if;
  if not exists (
    select 1
    from private.score_run_tickets as ticket
    where ticket.run_id = p_run_id
      and ticket.token_hash = p_run_token_hash
      and ticket.consumed_at is null
      and ticket.expires_at > clock_timestamp()
  ) then
    raise exception 'run ticket is missing, expired, or already used'
      using errcode = '22023';
  end if;

  if char_length(normalized_name) not between 1 and 16 then
    raise exception 'player_name must contain 1 to 16 characters'
      using errcode = '22023';
  end if;
  if normalized_name !~ '^[A-Z0-9@_.-]+$' then
    raise exception 'player_name contains unsupported characters'
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
  returning id into inserted_id;

  update private.score_run_tickets
  set consumed_at = clock_timestamp()
  where run_id = p_run_id;

  return query select inserted_id, true;
end;
$$;

revoke execute on function public.issue_score_run(uuid, text)
  from public, anon, authenticated;
revoke execute on function public.submit_score(
  uuid,
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
  integer,
  text,
  integer,
  integer
) to service_role;
