import { createClient } from "npm:@supabase/supabase-js@2";

const ALLOWED_WEB_ORIGINS = new Set([
  "https://adrianmg.github.io",
]);
const LOCAL_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;
const encoder = new TextEncoder();

type JsonRecord = Record<string, unknown>;


function isAllowedOrigin(origin: string | null): boolean {
  return (
    origin === null
    || ALLOWED_WEB_ORIGINS.has(origin)
    || LOCAL_ORIGIN.test(origin)
  );
}


function responseHeaders(origin: string | null): HeadersInit {
  return {
    "Access-Control-Allow-Headers": "apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Origin": origin ?? "*",
    "Cache-Control": "no-store",
    "Content-Type": "application/json",
    "Vary": "Origin",
  };
}


function jsonResponse(
  body: JsonRecord | unknown[],
  status: number,
  origin: string | null,
  extraHeaders: HeadersInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...responseHeaders(origin),
      ...extraHeaders,
    },
  });
}


async function digestNetworkKey(
  networkAddress: string,
  secret: string,
): Promise<string> {
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
    encoder.encode(networkAddress),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}


Deno.serve(async (request: Request): Promise<Response> => {
  const origin = request.headers.get("origin");
  if (!isAllowedOrigin(origin)) {
    return jsonResponse({ error: "Origin is not allowed." }, 403, origin);
  }
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: responseHeaders(origin),
    });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405, origin);
  }

  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (contentLength > 2048) {
    return jsonResponse({ error: "Request body is too large." }, 413, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Supabase function environment is incomplete.");
    return jsonResponse({ error: "Score service is unavailable." }, 503, origin);
  }

  const forwardedFor = request.headers.get("x-forwarded-for")
    ?.split(",")[0]
    ?.trim();
  const networkAddress = request.headers.get("cf-connecting-ip")
    ?? forwardedFor
    ?? "unknown";
  const keyHash = await digestNetworkKey(networkAddress, serviceRoleKey);
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: rateLimitRows, error: rateLimitError } = await admin.rpc(
    "consume_score_rate_limit",
    {
      p_key_hash: keyHash,
      p_limit: 5,
      p_window_seconds: 3600,
    },
  );
  if (rateLimitError || !rateLimitRows?.length) {
    console.error("Score rate limit failed.", rateLimitError);
    return jsonResponse({ error: "Score service is unavailable." }, 503, origin);
  }
  const rateLimit = rateLimitRows[0] as {
    allowed: boolean;
    retry_after_seconds: number;
  };
  if (!rateLimit.allowed) {
    return jsonResponse(
      { error: "Too many score submissions. Try again later." },
      429,
      origin,
      { "Retry-After": String(rateLimit.retry_after_seconds) },
    );
  }

  let payload: JsonRecord;
  try {
    payload = await request.json() as JsonRecord;
  } catch {
    return jsonResponse({ error: "Request body must be JSON." }, 400, origin);
  }
  const { data, error } = await admin.rpc("submit_score", {
    p_run_id: payload.run_id,
    p_player_name: payload.player_name,
    p_score: payload.score,
    p_outcome: payload.outcome,
    p_completed_stage: payload.completed_stage,
    p_start_stage: payload.start_stage,
  });
  if (error) {
    if (["22023", "23514", "22P02"].includes(error.code)) {
      return jsonResponse({ error: error.message }, 400, origin);
    }
    console.error("Score submission failed.", error);
    return jsonResponse({ error: "Score could not be saved." }, 500, origin);
  }

  const created = Boolean(data?.[0]?.created);
  return jsonResponse(data ?? [], created ? 201 : 200, origin);
});
