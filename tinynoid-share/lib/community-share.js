export const PUBLIC_URL = "https://tinynoid.vercel.app/";
export const SUPABASE_API =
  "https://ugkygoijpqrreooylpnc.supabase.co/functions/v1";
export const SUPABASE_REST = "https://ugkygoijpqrreooylpnc.supabase.co/rest/v1";
export const SUPABASE_PUBLISHABLE_KEY =
  "sb_publishable_GMQxCnYtLe3qCkV1Nc3N2w_5JXyve-X";
export const COMMUNITY_IMAGE_VERSION = "2";

const ID_PATTERN = /^cl_[0-9a-f]{24}$/;
const NAME_PATTERN = /^[A-Z0-9 @._-]+$/;
const ROW_PATTERN = /^[.WOCGRBPYSX]{13}$/;
export function isCommunityLevelId(value) {
  return typeof value === "string" && ID_PATTERN.test(value);
}

export function formatCreatorName(value) {
  const normalized = String(value ?? "").trim().toUpperCase();
  if (!normalized) return "UNKNOWN";
  return normalized.startsWith("@") ? normalized : `@${normalized}`;
}

export function parseCommunityLevel(value, expectedId) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Community response did not contain a level.");
  }
  if (
    value.id !== expectedId ||
    value.schema_version !== 1 ||
    !NAME_PATTERN.test(value.level_name) ||
    value.level_name.length < 2 ||
    value.level_name.length > 32 ||
    !NAME_PATTERN.test(value.creator_display_name) ||
    value.creator_display_name.length < 2 ||
    value.creator_display_name.length > 24 ||
    !Array.isArray(value.layout) ||
    value.layout.length !== 10 ||
    value.layout.some((row) =>
      typeof row !== "string" || !ROW_PATTERN.test(row)
    ) ||
    typeof value.created_at !== "string" ||
    Number.isNaN(Date.parse(value.created_at)) ||
    typeof value.slug !== "string" ||
    !/^[a-z0-9_-]{1,68}$/.test(value.slug) ||
    (value.status !== "pending" && value.status !== "listed")
  ) {
    throw new Error("Community response contained an invalid level.");
  }
  return {
    id: expectedId,
    level_name: value.level_name,
    creator_display_name: value.creator_display_name,
    layout: [...value.layout],
    created_at: value.created_at,
    slug: value.slug,
    status: value.status,
  };
}

export function communityPlayUrl(levelId) {
  if (!isCommunityLevelId(levelId)) return "";
  const url = new URL(PUBLIC_URL);
  url.searchParams.set("community", levelId);
  return url.href;
}

export function communityShareUrl(level, versioned = false) {
  const url = new URL(PUBLIC_URL);
  url.pathname = level.slug;
  if (versioned) url.searchParams.set("v", communityShareVersion(level));
  return url.href;
}

export function communityShareVersion(level) {
  return `${COMMUNITY_IMAGE_VERSION}-${level.status}`;
}

export function communityImageUrl(level, publicUrl = PUBLIC_URL) {
  if (!isCommunityLevelId(level?.id)) return "";
  const url = new URL(`og/level/${level.id}.png`, publicUrl);
  url.searchParams.set("v", communityShareVersion(level));
  return url.href;
}

function escapeHtml(value) {
  return value.replace(
    /[&<>"']/g,
    (character) =>
      ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      })[character],
  );
}

export function communitySharePage(level) {
  const shareUrl = communityShareUrl(level, true);
  const destination = communityPlayUrl(level.id);
  const imageUrl = communityImageUrl(level);
  const title = `${level.level_name} - TINYNOID Community Level`;
  const description = `Play ${level.level_name} by ${
    formatCreatorName(level.creator_display_name)
  } in TINYNOID.`;
  const escapedDestination = escapeHtml(destination);
  const escapedTitle = escapeHtml(title);
  const escapedDescription = escapeHtml(description);
  const escapedImageUrl = escapeHtml(imageUrl);
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="canonical" href="${escapeHtml(shareUrl)}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="TINYNOID">
  <meta property="og:url" content="${escapeHtml(shareUrl)}">
  <meta property="og:title" content="${escapedTitle}">
  <meta property="og:description" content="${escapedDescription}">
  <meta property="og:image" content="${escapedImageUrl}">
  <meta property="og:image:secure_url" content="${escapedImageUrl}">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="${escapedDescription}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapedTitle}">
  <meta name="twitter:description" content="${escapedDescription}">
  <meta name="twitter:image" content="${escapedImageUrl}">
  <meta name="twitter:image:alt" content="${escapedDescription}">
  <meta http-equiv="refresh" content="0;url=${escapedDestination}">
  <title>${escapedTitle}</title>
</head>
<body>
  <p><a href="${escapedDestination}">Play ${
    escapeHtml(level.level_name)
  } in TINYNOID</a></p>
</body>
</html>`;
}
