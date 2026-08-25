import { createClient } from "npm:@supabase/supabase-js@2";
import { parseSubmitDailyScore } from "../_shared/daily-challenge.ts";
import {
  digestNetworkIdentifier,
  networkIdentifier,
  readJsonBody,
  RequestValidationError,
} from "../_shared/community-levels.ts";
import {
  corsHeaders,
  errorResponse,
  isAllowedOrigin,
  jsonResponse,
  rejectedOriginResponse,
} from "../_shared/http.ts";

const METHODS = "POST, OPTIONS";
const encoder = new TextEncoder();

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (request: Request): Promise<Response> => {
  const origin = request.headers.get("origin");
  if (!isAllowedOrigin(origin)) return rejectedOriginResponse(METHODS);
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

  let payload;
  try {
    payload = parseSubmitDailyScore(await readJsonBody(request));
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
    throw error;
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return errorResponse(
      "service_unavailable",
      "Daily score could not be saved.",
      503,
      origin,
      METHODS,
    );
  }
  const rateKey = await digestNetworkIdentifier(
    `daily-score:${payload.daily_id}:${networkIdentifier(request)}`,
    serviceRoleKey,
  );
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await admin.rpc("submit_daily_score", {
    p_run_id: payload.run_id,
    p_token_hash: await sha256(payload.run_token),
    p_rate_key: rateKey,
    p_daily_id: payload.daily_id,
    p_level_id: payload.level_id,
    p_player_name: payload.player_name,
    p_score: payload.score,
    p_outcome: payload.outcome,
  });
  if (error || !data?.length) {
    const rateLimited = error?.code === "P0001" &&
      error.message === "daily_score_rate_limit_exceeded";
    const validation = ["22023", "23514", "22P02"].includes(
      error?.code ?? "",
    );
    if (!rateLimited && !validation) {
      console.error("Daily score submission failed.", error);
    }
    return errorResponse(
      rateLimited ? "rate_limit_exceeded" : "daily_score_failed",
      rateLimited
        ? "Too many Daily Cartridge scores. Try again later."
        : "Daily score could not be saved.",
      rateLimited ? 429 : validation ? 400 : 500,
      origin,
      METHODS,
      rateLimited ? { "Retry-After": "3600" } : undefined,
    );
  }
  const row = data[0];
  return jsonResponse(
    {
      run_id: payload.run_id,
      created: Boolean(row.created),
      rank: Number(row.rank),
      best_score: Number(row.best_score),
      competitor_count: Number(row.competitor_count),
      personal_best: Boolean(row.personal_best),
      submitted_at: new Date().toISOString(),
    },
    Boolean(row.created) ? 201 : 200,
    origin,
    METHODS,
  );
});
