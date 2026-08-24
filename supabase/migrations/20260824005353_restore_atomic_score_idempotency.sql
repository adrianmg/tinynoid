create or replace function public.submit_score(
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

  if p_score not between 0 and 999999 then
    raise exception 'score is outside the supported range'
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
