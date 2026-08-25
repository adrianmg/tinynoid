import { createClient } from "npm:@supabase/supabase-js@2";
import {
  parseSharedLevel,
  parseShareQuery,
} from "../_shared/community-share.ts";
import { RequestValidationError } from "../_shared/community-levels.ts";
import { publicErrorResponse } from "../_shared/http.ts";
import { renderCommunityLevelImage } from "./share-image.tsx";

const METHODS = "GET, HEAD";

function withHeaders(response: Response, cacheControl: string): Response {
  const headers = new Headers(response.headers);
  headers.set("Cache-Control", cacheControl);
  headers.set("Referrer-Policy", "no-referrer");
  headers.set("X-Content-Type-Options", "nosniff");
  return new Response(response.body, {
    status: response.status,
    headers,
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return publicErrorResponse(
      "method_not_allowed",
      "Method not allowed.",
      405,
      METHODS,
      { Allow: METHODS },
    );
  }

  let query;
  try {
    query = parseShareQuery(new URL(request.url));
  } catch (error) {
    if (error instanceof RequestValidationError) {
      return publicErrorResponse(
        error.code,
        error.message,
        error.status,
        METHODS,
      );
    }
    console.error("Community share query parsing failed.", error);
    return publicErrorResponse(
      "internal_error",
      "Community share is unavailable.",
      500,
      METHODS,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Supabase function environment is incomplete.");
    return publicErrorResponse(
      "service_unavailable",
      "Community share is unavailable.",
      503,
      METHODS,
    );
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
  const { data, error } = await admin.rpc("get_community_levels", {
    p_limit: 1,
    p_id: query.id,
  });
  if (error) {
    console.error("Community share lookup failed.", error);
    return publicErrorResponse(
      "share_failed",
      "Community share is unavailable.",
      500,
      METHODS,
    );
  }
  if (!Array.isArray(data) || data.length === 0) {
    return publicErrorResponse(
      "level_unavailable",
      "Community level is no longer available.",
      404,
      METHODS,
    );
  }

  let level;
  try {
    level = parseSharedLevel(data[0], query.id);
  } catch (error) {
    console.error("Community share data was invalid.", error);
    return publicErrorResponse(
      "share_failed",
      "Community share is unavailable.",
      500,
      METHODS,
    );
  }

  if (query.image) {
    const response = withHeaders(
      renderCommunityLevelImage(level),
      "public, max-age=3600, s-maxage=86400",
    );
    if (request.method === "HEAD") {
      return new Response(null, {
        status: response.status,
        headers: response.headers,
      });
    }
    return response;
  }

  return new Response(null, {
    status: 308,
    headers: {
      "Cache-Control": "public, max-age=300",
      Location: `https://tinynoid.vercel.app/level/${level.id}`,
      "Referrer-Policy": "no-referrer",
      "X-Content-Type-Options": "nosniff",
    },
  });
});
