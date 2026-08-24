create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table private.score_submission_limits (
  key_hash text primary key,
  window_started_at timestamptz not null,
  attempt_count integer not null
);

create table private.blocked_player_name_terms (
  term text primary key
);

insert into private.blocked_player_name_terms (term)
values
  ('FAGGOT'),
  ('FUCK'),
  ('NIGGER'),
  ('SHIT')
on conflict (term) do nothing;

alter table public.scores
  add column start_stage smallint not null default 1,
  add constraint scores_start_stage check (start_stage = 1);

alter table public.scores
  drop constraint scores_player_name_characters,
  add constraint scores_player_name_characters check (
    player_name ~ '^[A-Z0-9@_.-]+$'
  );

drop function public.submit_score(uuid, text, integer, text, integer);

create function public.submit_score(
  p_run_id uuid,
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
begin
  if p_run_id is null then
    raise exception 'run_id is required' using errcode = '22023';
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

  if p_score not between 0 and 217290 then
    raise exception 'score is outside the campaign range'
      using errcode = '22023';
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
  on conflict (run_id) do nothing
  returning id into inserted_id;

  if inserted_id is not null then
    return query select inserted_id, true;
    return;
  end if;

  return query
  select existing.id, false
  from public.scores as existing
  where existing.run_id = p_run_id;
end;
$$;

create function public.consume_score_rate_limit(
  p_key_hash text,
  p_limit integer default 5,
  p_window_seconds integer default 3600
)
returns table(allowed boolean, retry_after_seconds integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_time timestamptz := clock_timestamp();
  current_count integer;
  current_window timestamptz;
begin
  if char_length(p_key_hash) <> 64 then
    raise exception 'rate-limit key must be a SHA-256 digest'
      using errcode = '22023';
  end if;
  if p_limit not between 1 and 100 then
    raise exception 'rate-limit count is invalid' using errcode = '22023';
  end if;
  if p_window_seconds not between 60 and 86400 then
    raise exception 'rate-limit window is invalid' using errcode = '22023';
  end if;

  insert into private.score_submission_limits (
    key_hash,
    window_started_at,
    attempt_count
  )
  values (p_key_hash, current_time, 1)
  on conflict (key_hash) do update
  set
    window_started_at = case
      when private.score_submission_limits.window_started_at
        <= current_time - make_interval(secs => p_window_seconds)
      then current_time
      else private.score_submission_limits.window_started_at
    end,
    attempt_count = case
      when private.score_submission_limits.window_started_at
        <= current_time - make_interval(secs => p_window_seconds)
      then 1
      else least(private.score_submission_limits.attempt_count + 1, 32767)
    end
  returning attempt_count, window_started_at
  into current_count, current_window;

  return query
  select
    current_count <= p_limit,
    case
      when current_count <= p_limit then 0
      else greatest(
        1,
        ceil(
          extract(
            epoch from (
              current_window
              + make_interval(secs => p_window_seconds)
              - current_time
            )
          )
        )::integer
      )
    end;
end;
$$;

revoke execute on function public.submit_score(
  uuid,
  text,
  integer,
  text,
  integer,
  integer
) from public, anon, authenticated;
revoke execute on function public.consume_score_rate_limit(
  text,
  integer,
  integer
) from public, anon, authenticated;

grant execute on function public.submit_score(
  uuid,
  text,
  integer,
  text,
  integer,
  integer
) to service_role;
grant execute on function public.consume_score_rate_limit(
  text,
  integer,
  integer
) to service_role;

comment on table private.blocked_player_name_terms is
  'Owner-managed denylist applied before public score names are displayed.';
comment on table private.score_submission_limits is
  'Hashed network identifiers used for anonymous submission throttling.';
