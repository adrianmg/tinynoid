import {
  isCommunityLevelId,
  parseCommunityLevel,
  SUPABASE_PUBLISHABLE_KEY,
  SUPABASE_REST,
} from "./community-share.js";

export async function resolveCommunityLevel(
  { id = null, slug = null, signal } = {},
) {
  if ((id === null) === (slug === null)) {
    throw new Error("Resolve a community level by exactly one identifier.");
  }
  if (id !== null && !isCommunityLevelId(id)) {
    return null;
  }

  const response = await fetch(
    `${SUPABASE_REST}/rpc/get_community_level_share`,
    {
      method: "POST",
      headers: {
        apikey: SUPABASE_PUBLISHABLE_KEY,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        p_id: id,
        p_slug: slug,
      }),
      signal,
    },
  );
  if (!response.ok) {
    throw new Error(`Community resolver returned ${response.status}.`);
  }
  const body = await response.json();
  if (!Array.isArray(body) || body.length === 0) {
    return null;
  }
  if (!isCommunityLevelId(body[0]?.id)) {
    throw new Error("Community resolver returned an invalid id.");
  }
  if (id !== null && body[0].id !== id) {
    throw new Error("Community resolver returned the wrong level.");
  }
  return parseCommunityLevel(body[0], id ?? body[0].id);
}
