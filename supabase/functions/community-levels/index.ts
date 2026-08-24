import { createClient } from "npm:@supabase/supabase-js@2";
import {
  parseCatalogQuery,
  RequestValidationError,
} from "../_shared/community-levels.ts";
import {
  corsHeaders,
  errorResponse,
  isAllowedOrigin,
  jsonResponse,
  rejectedOriginResponse,
} from "../_shared/http.ts";

const METHODS = "GET, OPTIONS";

Deno.serve(async (request: Request): Promise<Response> => {
  const origin = request.headers.get("origin");
  if (!isAllowedOrigin(origin)) {
    return rejectedOriginResponse(METHODS);
  }
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(origin, METHODS),
    });
  }
  if (request.method !== "GET") {
    return errorResponse(
      "method_not_allowed",
      "Method not allowed.",
      405,
      origin,
      METHODS,
      { Allow: METHODS },
    );
  }

  let query;
  try {
    query = parseCatalogQuery(new URL(request.url));
  } catch (error) {
    if (error instanceof RequestValidationError) {
      return errorResponse(
        error.code,
        error.message,
        error.status,
        origin,
        METHODS,
      );
    }
    console.error("Community catalog query parsing failed.", error);
    return errorResponse(
      "internal_error",
      "Level catalog is unavailable.",
      500,
      origin,
      METHODS,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Supabase function environment is incomplete.");
    return errorResponse(
      "service_unavailable",
      "Level catalog is unavailable.",
      503,
      origin,
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
    p_limit: query.limit,
    p_id: query.id,
  });
  if (error) {
    if (error.code === "22023") {
      return errorResponse(
        "invalid_query",
        error.message,
        400,
        origin,
        METHODS,
      );
    }
    console.error("Community catalog query failed.", error);
    return errorResponse(
      "catalog_failed",
      "Level catalog is unavailable.",
      500,
      origin,
      METHODS,
    );
  }

  return jsonResponse({ levels: data ?? [] }, 200, origin, METHODS);
});
