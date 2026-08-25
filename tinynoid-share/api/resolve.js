import {
  communityShareUrl,
  isCommunityLevelId,
} from "../lib/community-share.js";
import { resolveCommunityLevel } from "../lib/community-api.js";

export default {
  async fetch(request) {
    if (request.method !== "GET") {
      return new Response("Method not allowed.", {
        status: 405,
        headers: { Allow: "GET" },
      });
    }
    const id = new URL(request.url).searchParams.get("id");
    if (!isCommunityLevelId(id)) {
      return Response.json({ error: "Invalid community level id." }, {
        status: 400,
      });
    }
    try {
      const level = await resolveCommunityLevel({
        id,
        signal: AbortSignal.timeout(8000),
      });
      if (!level) {
        return Response.json({ error: "Community level is unavailable." }, {
          status: 404,
        });
      }
      return Response.json({
        id: level.id,
        slug: level.slug,
        share_url: communityShareUrl(level),
      }, {
        headers: {
          "Cache-Control": "public, s-maxage=300, stale-while-revalidate=86400",
        },
      });
    } catch (error) {
      console.error("Community share URL resolution failed.", error);
      return Response.json({ error: "Community share is unavailable." }, {
        status: 503,
      });
    }
  },
};
