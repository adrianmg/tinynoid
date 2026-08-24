create or replace function public.consume_score_rate_limit(
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
  request_time timestamptz := clock_timestamp();
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
  values (p_key_hash, request_time, 1)
  on conflict (key_hash) do update
  set
    window_started_at = case
      when private.score_submission_limits.window_started_at
        <= request_time - make_interval(secs => p_window_seconds)
      then request_time
      else private.score_submission_limits.window_started_at
    end,
    attempt_count = case
      when private.score_submission_limits.window_started_at
        <= request_time - make_interval(secs => p_window_seconds)
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
              - request_time
            )
          )
        )::integer
      )
    end;
end;
$$;
