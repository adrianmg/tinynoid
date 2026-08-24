begin;

do $$
declare
  first_id text;
  duplicate_id text;
  first_created boolean;
  duplicate_created boolean;
  visible_count integer;
  content_before jsonb;
  content_after jsonb;
  rate_allowed boolean;
  retry_seconds integer;
  event_count integer;
  attempt integer;
begin
  if has_table_privilege('anon', 'public.community_levels', 'select')
    or has_table_privilege('anon', 'public.community_levels', 'insert')
    or has_table_privilege(
      'authenticated',
      'public.community_levels',
      'select'
    )
    or has_table_privilege(
      'authenticated',
      'public.community_levels',
      'insert'
    )
  then
    raise exception 'community_levels grants expose direct access';
  end if;

  if has_function_privilege(
    'anon',
    'public.submit_community_level(integer,text,text,text[])',
    'execute'
  ) or has_function_privilege(
    'authenticated',
    'public.get_community_levels(integer,text)',
    'execute'
  ) then
    raise exception 'community level RPC grants expose public execution';
  end if;

  select level_id, created
  into first_id, first_created
  from public.submit_community_level(
    1,
    E'  smoke\t level  ',
    '  sql   test ',
    array[
      'WOCGRBPYSX...',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............'
    ]
  );
  if not first_created
    or first_id <> 'cl_fc0df619c771afc1dd761aa3'
  then
    raise exception 'first submission did not create a stable public id';
  end if;

  select level_id, created
  into duplicate_id, duplicate_created
  from public.submit_community_level(
    1,
    'SMOKE LEVEL',
    'SQL TEST',
    array[
      'WOCGRBPYSX...',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............',
      '.............'
    ]
  );
  if duplicate_created or duplicate_id <> first_id then
    raise exception 'canonical duplicate was not idempotent';
  end if;

  select count(*) into visible_count
  from public.get_community_levels(50, first_id);
  if visible_count <> 1 then
    raise exception 'pending level was not visible';
  end if;

  select to_jsonb(level) - 'created_at' - 'content_hash'
  into content_before
  from public.community_levels as level
  where level.id = first_id;

  begin
    update public.community_levels
    set level_name = 'MUTATED'
    where id = first_id;
    raise exception 'immutable level update unexpectedly succeeded';
  exception
    when sqlstate '55000' then null;
  end;

  select to_jsonb(level) - 'created_at' - 'content_hash'
  into content_after
  from public.community_levels as level
  where level.id = first_id;
  if content_after is distinct from content_before then
    raise exception 'immutable level content changed';
  end if;

  perform public.moderate_community_level(
    first_id,
    'listed',
    'sql-smoke',
    'approved'
  );
  select count(*) into visible_count
  from public.get_community_levels(50, first_id);
  if visible_count <> 1 then
    raise exception 'listed level was not visible';
  end if;

  perform public.moderate_community_level(
    first_id,
    'quarantined',
    'sql-smoke',
    'review required'
  );
  select count(*) into visible_count
  from public.get_community_levels(50, first_id);
  if visible_count <> 0 then
    raise exception 'quarantined level remained visible';
  end if;

  perform public.moderate_community_level(
    first_id,
    'pending',
    'sql-smoke',
    'returned to review'
  );
  perform public.moderate_community_level(
    first_id,
    'removed',
    'sql-smoke',
    'smoke removal'
  );
  select count(*) into visible_count
  from public.get_community_levels(50, first_id);
  if visible_count <> 0 then
    raise exception 'removed level remained visible';
  end if;
  select count(*) into event_count
  from private.community_level_moderation_events
  where level_id = first_id
    and actor = 'sql-smoke'
    and changed_at is not null;
  if event_count <> 4 then
    raise exception 'moderation audit trail did not record every transition';
  end if;

  begin
    perform public.moderate_community_level(
      first_id,
      'listed',
      'sql-smoke',
      'invalid restoration'
    );
    raise exception 'illegal moderation transition unexpectedly succeeded';
  exception
    when sqlstate '22023' then null;
  end;

  delete from private.community_level_submission_limits
  where key_hash = repeat('a', 64);
  for attempt in 1..6 loop
    select allowed, retry_after_seconds
    into rate_allowed, retry_seconds
    from public.consume_community_level_rate_limit(repeat('a', 64));
    if attempt <= 5 and not rate_allowed then
      raise exception 'rate limit rejected attempt % too early', attempt;
    end if;
  end loop;
  if rate_allowed or retry_seconds < 1 or retry_seconds > 3600 then
    raise exception 'five-per-hour rate limit was not enforced';
  end if;
end;
$$;

rollback;
