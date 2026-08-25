import {
  communitySharePage,
  isCommunityLevelId,
} from "../lib/community-share.js";
import { resolveCommunityLevel } from "../lib/community-api.js";

function errorResponse(message, status, cacheControl = "no-store") {
  return new Response(message, {
    status,
    headers: {
      "Cache-Control": cacheControl,
      "Content-Type": "text/plain; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

async function handle(request) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed.", {
      status: 405,
      headers: {
        Allow: "GET, HEAD",
        "Cache-Control": "no-store",
        "Content-Type": "text/plain; charset=utf-8",
      },
    });
  }

  const requestUrl = new URL(request.url);
  const rawSlug = requestUrl.searchParams.get("slug") ?? "";
  const legacyRoute = requestUrl.searchParams.get("legacy") === "1";
  const requestedSlug = rawSlug.toLowerCase();
  if (!requestedSlug || !/^[a-z0-9_-]{1,68}$/.test(requestedSlug)) {
    return errorResponse("Community level slug is required.", 400);
  }

  let level;
  try {
    level = await resolveCommunityLevel({
      id: isCommunityLevelId(requestedSlug) ? requestedSlug : null,
      slug: isCommunityLevelId(requestedSlug) ? null : requestedSlug,
      signal: AbortSignal.timeout(8000),
    });
  } catch (error) {
    console.error("Community share lookup could not start.", error);
    return errorResponse("Community share is temporarily unavailable.", 503);
  }
  if (!level) {
    return errorResponse(
      "Community level is no longer available.",
      404,
      "public, s-maxage=60",
    );
  }

  if (legacyRoute || rawSlug !== level.slug) {
    return new Response(null, {
      status: 308,
      headers: {
        "Cache-Control": "public, max-age=300",
        Location: new URL(`/${level.slug}`, requestUrl.origin).href,
      },
    });
  }

  const html = communitySharePage(level);
  const headers = {
    "Cache-Control": "public, s-maxage=300, stale-while-revalidate=3600",
    "Content-Security-Policy":
      "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
    "Content-Type": "text/html; charset=utf-8",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
  };
  return new Response(request.method === "HEAD" ? null : html, {
    status: 200,
    headers,
  });
}

export default {
  fetch: handle,
};
