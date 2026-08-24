create policy community_levels_deny_public
on public.community_levels
for all
to anon, authenticated
using (false)
with check (false);

create policy community_level_moderation_deny_public
on private.community_level_moderation
for all
to anon, authenticated
using (false)
with check (false);

create policy community_level_moderation_events_deny_public
on private.community_level_moderation_events
for all
to anon, authenticated
using (false)
with check (false);

create policy community_level_submission_limits_deny_public
on private.community_level_submission_limits
for all
to anon, authenticated
using (false)
with check (false);
