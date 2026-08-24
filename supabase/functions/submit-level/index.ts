import { createClient } from "npm:@supabase/supabase-js@2";
import {
  canonicalizeSubmission,
  digestNetworkIdentifier,
  hashCanonicalText,
  networkIdentifier,
  readJsonBody,
  RequestValidationError,
  submissionResult,
} from "../_shared/community-levels.ts";
import {
  corsHeaders,
  errorResponse,
  isAllowedOrigin,
  jsonResponse,
  rateLimitResponse,
  rejectedOriginResponse,
} from "../_shared/http.ts";

const METHODS = "POST, OPTIONS";

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
  if (request.method !== "POST") {
    return errorResponse(
      "method_not_allowed",
      "Method not allowed.",
      405,
      origin,
      METHODS,
      { Allow: METHODS },
    );
  }

  let submission;
  try {
    submission = canonicalizeSubmission(await readJsonBody(request));
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
    console.error("Level request parsing failed.", error);
    return errorResponse(
      "internal_error",
      "Level service is unavailable.",
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
      "Level service is unavailable.",
      503,
      origin,
      METHODS,
    );
  }

  const keyHash = await digestNetworkIdentifier(
    networkIdentifier(request),
    serviceRoleKey,
  );
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
  const { data: rateLimitRows, error: rateLimitError } = await admin.rpc(
    "consume_community_level_rate_limit",
    { p_key_hash: keyHash },
  );
  if (rateLimitError || !Array.isArray(rateLimitRows) || !rateLimitRows[0]) {
    console.error("Community level rate limit failed.", rateLimitError);
    return errorResponse(
      "service_unavailable",
      "Level service is unavailable.",
      503,
      origin,
      METHODS,
    );
  }

  const rateLimit = rateLimitRows[0] as {
    allowed?: unknown;
    retry_after_seconds?: unknown;
  };
  if (
    typeof rateLimit.allowed !== "boolean" ||
    typeof rateLimit.retry_after_seconds !== "number"
  ) {
    console.error("Community level rate limit returned an invalid result.");
    return errorResponse(
      "service_unavailable",
      "Level service is unavailable.",
      503,
      origin,
      METHODS,
    );
  }
  if (!rateLimit.allowed) {
    return rateLimitResponse(origin, rateLimit.retry_after_seconds);
  }

  const { publicId } = await hashCanonicalText(submission.canonical_text);
  const { data, error } = await admin.rpc("submit_community_level", {
    p_schema_version: submission.schema_version,
    p_level_name: submission.level_name,
    p_creator_display_name: submission.creator_display_name,
    p_layout: submission.layout,
  });
  if (error) {
    if (["22023", "23514", "22P02"].includes(error.code)) {
      return errorResponse(
        "invalid_request",
        error.message,
        400,
        origin,
        METHODS,
      );
    }
    console.error("Community level submission failed.", error);
    return errorResponse(
      "submission_failed",
      "Level could not be saved.",
      500,
      origin,
      METHODS,
    );
  }

  let result;
  if (data?.[0]?.status === "unavailable") {
    return errorResponse(
      "level_unavailable",
      "This level already exists but is not publicly available.",
      409,
      origin,
      METHODS,
    );
  }
  try {
    result = submissionResult(data?.[0], publicId);
  } catch (error) {
    console.error("Community level submission result was invalid.", error);
    return errorResponse(
      "submission_failed",
      "Level could not be saved.",
      500,
      origin,
      METHODS,
    );
  }
  return jsonResponse(result, result.created ? 201 : 200, origin, METHODS);
});
