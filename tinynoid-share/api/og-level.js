import {
  COMMUNITY_IMAGE_VERSION,
  communityShareVersion,
  isCommunityLevelId,
  SUPABASE_API,
} from "../lib/community-share.js";
import { resolveCommunityLevel } from "../lib/community-api.js";

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const PNG_SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10];

function errorResponse(message, status) {
  return new Response(message, {
    status,
    headers: {
      "Cache-Control": "no-store",
      "Content-Type": "text/plain; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function isExpectedPng(bytes) {
  if (bytes.byteLength < 24) return false;
  if (!PNG_SIGNATURE.every((byte, index) => bytes[index] === byte)) {
    return false;
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  return view.getUint32(16) === 1200 && view.getUint32(20) === 630;
}

export async function handle(
  request,
  fetchImage = fetch,
  resolveLevel = resolveCommunityLevel,
) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed.", {
      status: 405,
      headers: {
        Allow: "GET, HEAD",
        "Cache-Control": "no-store",
      },
    });
  }

  const requestUrl = new URL(request.url);
  const queryKeys = [...requestUrl.searchParams.keys()];
  if (
    queryKeys.some((key) => key !== "id" && key !== "v") ||
    requestUrl.searchParams.getAll("id").length !== 1 ||
    requestUrl.searchParams.getAll("v").length !== 1
  ) {
    return errorResponse("Invalid community OG image query.", 400);
  }
  const id = requestUrl.searchParams.get("id");
  if (!isCommunityLevelId(id)) {
    return errorResponse("Invalid community level id.", 400);
  }
  let level;
  try {
    level = await resolveLevel({
      id,
      signal: AbortSignal.timeout(8000),
    });
  } catch (error) {
    console.error("Community OG level lookup failed.", error);
    return errorResponse("Community OG image is unavailable.", 502);
  }
  const requestedVersion = requestUrl.searchParams.get("v");
  const allowedVersions = level
    ? [communityShareVersion(level)]
    : [];
  if (level?.status === "listed") {
    allowedVersions.push(`${COMMUNITY_IMAGE_VERSION}-pending`);
  }
  if (!level || !allowedVersions.includes(requestedVersion)) {
    return errorResponse("Community OG image is unavailable.", 404);
  }

  const upstreamUrl = new URL(`${SUPABASE_API}/share-level`);
  upstreamUrl.searchParams.set("id", id);
  upstreamUrl.searchParams.set("image", "1");

  let upstream;
  try {
    upstream = await fetchImage(upstreamUrl, {
      headers: { Accept: "image/png" },
      signal: AbortSignal.timeout(8000),
    });
  } catch (error) {
    console.error("Community OG image request failed.", error);
    return errorResponse("Community OG image is unavailable.", 502);
  }
  const contentType = String(
    upstream.headers.get("content-type") ?? "",
  ).toLowerCase();
  if (!upstream.ok || !contentType.startsWith("image/png")) {
    console.error(
      "Community OG image upstream returned an invalid response.",
      upstream.status,
      upstream.headers.get("content-type"),
    );
    return errorResponse("Community OG image is unavailable.", 502);
  }

  const declaredLength = Number(upstream.headers.get("content-length") ?? "0");
  if (declaredLength > MAX_IMAGE_BYTES) {
    return errorResponse("Community OG image is too large.", 502);
  }
  const bytes = new Uint8Array(await upstream.arrayBuffer());
  if (bytes.byteLength > MAX_IMAGE_BYTES || !isExpectedPng(bytes)) {
    return errorResponse("Community OG image is invalid.", 502);
  }

  const headers = {
    "Cache-Control":
      "public, max-age=300, s-maxage=300, stale-while-revalidate=3600",
    "Content-Length": String(bytes.byteLength),
    "Content-Type": "image/png",
    "Cross-Origin-Resource-Policy": "cross-origin",
    "X-Content-Type-Options": "nosniff",
  };
  return new Response(request.method === "HEAD" ? null : bytes, {
    status: 200,
    headers,
  });
}

export function createOgLevelHandler(
  fetchImage = fetch,
  resolveLevel = resolveCommunityLevel,
) {
  return {
    fetch: (request) => handle(request, fetchImage, resolveLevel),
  };
}

export default createOgLevelHandler();
