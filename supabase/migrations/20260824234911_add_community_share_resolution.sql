create or replace function private.community_level_slug(p_level_name text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select case
    when normalized_slug in (
      'api',
      'editor',
      'favicon',
      'index',
      'level',
      'og-image',
      'robots',
      'schema'
    )
    then 'level-' || normalized_slug
    else normalized_slug
  end
  from (
    select coalesce(
      nullif(
        trim(
          both '-' from regexp_replace(
            lower(btrim(p_level_name)),
            '[^a-z0-9]+',
            '-',
            'g'
          )
        ),
        ''
      ),
      'community-level'
    ) as normalized_slug
  ) as slug_value;
$$;

create or replace function public.get_community_level_share(
  p_id text default null,
  p_slug text default null
)
returns table(
  id text,
  schema_version smallint,
  level_name text,
  creator_display_name text,
  layout text[],
  populated_count smallint,
  created_at timestamptz,
  status text,
  slug text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_id text;
begin
  if (p_id is null) = (p_slug is null) then
    raise exception 'Provide exactly one of p_id or p_slug'
      using errcode = '22023';
  end if;
  if p_id is not null and p_id !~ '^cl_[0-9a-f]{24}$' then
    raise exception 'p_id is invalid' using errcode = '22023';
  end if;
  if p_slug is not null and (
    char_length(p_slug) not between 1 and 68
    or p_slug !~ '^[a-z0-9_-]+$'
  ) then
    raise exception 'p_slug is invalid' using errcode = '22023';
  end if;

  if p_id is not null then
    target_id := p_id;
  else
    select level.id
    into target_id
    from public.community_levels as level
    where (
      private.community_level_slug(level.level_name) = p_slug
      or private.community_level_slug(level.level_name) || '-' || level.id
        = p_slug
    )
    order by level.created_at, level.id
    limit 1;
  end if;

  return query
  with target as (
    select
      level.id,
      level.schema_version,
      level.level_name,
      level.creator_display_name,
      level.layout,
      level.populated_count,
      level.created_at,
      moderation.status,
      private.community_level_slug(level.level_name) as base_slug
    from public.community_levels as level
    join private.community_level_moderation as moderation
      on moderation.level_id = level.id
    where level.id = target_id
      and moderation.status in ('pending', 'listed')
  ),
  resolved as (
    select
      target.*,
      case
        when exists (
          select 1
          from public.community_levels as older
          where private.community_level_slug(older.level_name)
            = target.base_slug
            and (older.created_at, older.id)
              < (target.created_at, target.id)
        )
        then target.base_slug || '-' || target.id
        else target.base_slug
      end as canonical_slug
    from target
  )
  select
    resolved.id,
    resolved.schema_version,
    resolved.level_name,
    resolved.creator_display_name,
    resolved.layout,
    resolved.populated_count,
    resolved.created_at,
    resolved.status,
    resolved.canonical_slug
  from resolved
  where p_slug is null or resolved.canonical_slug = p_slug;
end;
$$;

revoke all on function private.community_level_slug(text)
from public, anon, authenticated;

revoke all on function public.get_community_level_share(text, text)
from public;

grant execute on function public.get_community_level_share(text, text)
to anon, authenticated;
