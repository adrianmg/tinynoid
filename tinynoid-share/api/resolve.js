import {
  communityImageUrl,
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
      const imageUrl = communityImageUrl(level, new URL("/", request.url));
      try {
        const imageResponse = await fetch(imageUrl, {
          headers: { Accept: "image/png" },
          signal: AbortSignal.timeout(8000),
        });
        if (!imageResponse.ok) {
          throw new Error(`OG image returned ${imageResponse.status}.`);
        }
        await imageResponse.arrayBuffer();
      } catch (error) {
        console.warn("Community share image could not be warmed.", error);
      }
      return Response.json({
        id: level.id,
        slug: level.slug,
        share_url: communityShareUrl(level, true),
        image_url: imageUrl,
      }, {
        headers: {
          "Cache-Control": "no-store",
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
