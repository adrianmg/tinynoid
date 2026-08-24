create or replace function public.consume_community_level_rate_limit(
  p_key_hash text
)
returns table(allowed boolean, retry_after_seconds integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_count integer;
  v_window_started_at timestamptz;
begin
  if p_key_hash is null or p_key_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'rate-limit key must be a SHA-256 digest'
      using errcode = '22023';
  end if;

  delete from private.community_level_submission_limits as old_limit
  where old_limit.window_started_at < v_now - interval '2 hours'
    and old_limit.key_hash <> p_key_hash;

  insert into private.community_level_submission_limits (
    key_hash,
    window_started_at,
    attempt_count
  )
  values (p_key_hash, v_now, 1)
  on conflict (key_hash) do update
  set
    window_started_at = case
      when private.community_level_submission_limits.window_started_at
        <= v_now - interval '1 hour'
      then v_now
      else private.community_level_submission_limits.window_started_at
    end,
    attempt_count = case
      when private.community_level_submission_limits.window_started_at
        <= v_now - interval '1 hour'
      then 1
      else least(
        private.community_level_submission_limits.attempt_count + 1,
        32767
      )
    end
  returning attempt_count, window_started_at
  into v_count, v_window_started_at;

  return query
  select
    v_count <= 5,
    case
      when v_count <= 5 then 0
      else greatest(
        1,
        ceil(extract(
          epoch from (v_window_started_at + interval '1 hour' - v_now)
        ))::integer
      )
    end;
end;
$$;

revoke execute on function public.consume_community_level_rate_limit(text)
  from public, anon, authenticated;
grant execute on function public.consume_community_level_rate_limit(text)
  to service_role;
