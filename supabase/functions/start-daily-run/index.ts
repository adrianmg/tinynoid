import { createClient } from "npm:@supabase/supabase-js@2";
import { parseStartDailyRun } from "../_shared/daily-challenge.ts";
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

async function hexHmac(value: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

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
    payload = parseStartDailyRun(await readJsonBody(request));
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
      "Daily Cartridge could not start.",
      503,
      origin,
      METHODS,
    );
  }
  const runToken = await hexHmac(
    `daily:${payload.daily_id}:${payload.run_id}`,
    serviceRoleKey,
  );
  const rateKey = await digestNetworkIdentifier(
    `daily-ticket:${payload.daily_id}:${networkIdentifier(request)}`,
    serviceRoleKey,
  );
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await admin.rpc("issue_daily_run", {
    p_run_id: payload.run_id,
    p_daily_id: payload.daily_id,
    p_token_hash: await sha256(runToken),
    p_rate_key: rateKey,
  });
  if (error || !data?.length) {
    const rateLimited = error?.code === "P0001" &&
      error.message === "daily_run_rate_limit_exceeded";
    const unavailable = error?.code === "P0001" &&
      error.message === "daily_cartridge_unavailable";
    const validation = ["22023", "22P02"].includes(error?.code ?? "");
    if (!rateLimited && !unavailable && !validation) {
      console.error("Daily run ticket failed.", error);
    }
    return errorResponse(
      rateLimited
        ? "rate_limit_exceeded"
        : unavailable
        ? "daily_unavailable"
        : "daily_start_failed",
      rateLimited
        ? "Too many Daily Cartridge starts. Try again later."
        : unavailable
        ? "Daily Cartridge is unavailable."
        : "Daily Cartridge could not start.",
      rateLimited ? 429 : unavailable ? 404 : validation ? 400 : 500,
      origin,
      METHODS,
      rateLimited ? { "Retry-After": "3600" } : undefined,
    );
  }
  return jsonResponse(
    {
      run_id: payload.run_id,
      daily_id: String(data[0].daily_id),
      level_id: String(data[0].level_id),
      run_seed: Number(data[0].run_seed),
      run_token: runToken,
      expires_at: String(data[0].expires_at),
    },
    201,
    origin,
    METHODS,
  );
});
