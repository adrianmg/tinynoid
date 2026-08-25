import { createClient } from "npm:@supabase/supabase-js@2";
import {
  parseDailyCartridgeRow,
  parseDailyId,
  parseDailyRankRows,
} from "../_shared/daily-challenge.ts";
import {
  corsHeaders,
  errorResponse,
  isAllowedOrigin,
  jsonResponse,
  rejectedOriginResponse,
} from "../_shared/http.ts";
import { RequestValidationError } from "../_shared/community-levels.ts";

const METHODS = "GET, HEAD, OPTIONS";

Deno.serve(async (request: Request): Promise<Response> => {
  const origin = request.headers.get("origin");
  if (!isAllowedOrigin(origin)) return rejectedOriginResponse(METHODS);
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(origin, METHODS),
    });
  }
  if (request.method !== "GET" && request.method !== "HEAD") {
    return errorResponse(
      "method_not_allowed",
      "Method not allowed.",
      405,
      origin,
      METHODS,
      { Allow: METHODS },
    );
  }

  let dailyId: string | null = null;
  try {
    const url = new URL(request.url);
    if (
      [...url.searchParams.keys()].some((key) => key !== "date") ||
      url.searchParams.getAll("date").length > 1
    ) {
      throw new RequestValidationError(
        "invalid_request",
        "Unsupported daily challenge query.",
      );
    }
    const rawDate = url.searchParams.get("date");
    dailyId = rawDate === null ? null : parseDailyId(rawDate);
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
    console.error("Daily challenge environment is incomplete.");
    return errorResponse(
      "service_unavailable",
      "Daily Cartridge is unavailable.",
      503,
      origin,
      METHODS,
    );
  }
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: cartridgeRows, error: cartridgeError } = await admin.rpc(
    "get_daily_cartridge",
    { p_daily_id: dailyId },
  );
  if (cartridgeError) {
    const unavailable = cartridgeError.code === "P0001";
    const invalid = cartridgeError.code === "22023";
    if (!unavailable && !invalid) {
      console.error("Daily cartridge lookup failed.", cartridgeError);
    }
    return errorResponse(
      unavailable
        ? "daily_unavailable"
        : invalid
        ? "invalid_request"
        : "daily_failed",
      unavailable
        ? "No Daily Cartridge is available."
        : invalid
        ? cartridgeError.message
        : "Daily Cartridge could not be loaded.",
      unavailable ? 404 : invalid ? 400 : 500,
      origin,
      METHODS,
    );
  }
  if (!Array.isArray(cartridgeRows) || cartridgeRows.length !== 1) {
    return errorResponse(
      "daily_unavailable",
      "No Daily Cartridge is available.",
      404,
      origin,
      METHODS,
    );
  }

  try {
    const cartridge = parseDailyCartridgeRow(cartridgeRows[0]);
    const { data: scoreRows, error: scoreError } = await admin.rpc(
      "get_daily_scores",
      { p_daily_id: cartridge.daily_id, p_limit: 100 },
    );
    if (scoreError) throw scoreError;
    const body = {
      ...cartridge,
      server_now: new Date().toISOString(),
      top_scores: parseDailyRankRows(scoreRows ?? []),
    };
    return new Response(
      request.method === "HEAD" ? null : JSON.stringify(body),
      {
        status: 200,
        headers: {
          ...Object.fromEntries(corsHeaders(origin, METHODS)),
          "Cache-Control": "no-store",
        },
      },
    );
  } catch (error) {
    console.error("Daily challenge response was invalid.", error);
    return errorResponse(
      "daily_failed",
      "Daily Cartridge could not be loaded.",
      502,
      origin,
      METHODS,
    );
  }
});
