import { createClient } from "npm:@supabase/supabase-js@2";

const ALLOWED_WEB_ORIGINS = new Set([
  "https://adrianmg.github.io",
]);
const LOCAL_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;
const encoder = new TextEncoder();


function isAllowedOrigin(origin: string | null): boolean {
  return (
    origin === null
    || ALLOWED_WEB_ORIGINS.has(origin)
    || LOCAL_ORIGIN.test(origin)
  );
}


function headers(origin: string | null): HeadersInit {
  return {
    "Access-Control-Allow-Headers": "apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Origin": origin ?? "*",
    "Cache-Control": "no-store",
    "Content-Type": "application/json",
    "Vary": "Origin",
  };
}


function json(
  body: Record<string, unknown>,
  status: number,
  origin: string | null,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: headers(origin),
  });
}


async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    encoder.encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
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


async function createToken(runId: string, secret: string): Promise<string> {
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
    encoder.encode(`run:${runId}`),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}


Deno.serve(async (request: Request): Promise<Response> => {
  const origin = request.headers.get("origin");
  if (!isAllowedOrigin(origin)) {
    return json({ error: "Origin is not allowed." }, 403, origin);
  }
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: headers(origin) });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Supabase function environment is incomplete.");
    return json({ error: "Run service is unavailable." }, 503, origin);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json() as Record<string, unknown>;
  } catch {
    return json({ error: "Request body must be JSON." }, 400, origin);
  }
  if (typeof payload.run_id !== "string") {
    return json({ error: "run_id is required." }, 400, origin);
  }

  const token = await createToken(payload.run_id, serviceRoleKey);
  const forwardedFor = request.headers.get("x-forwarded-for")
    ?.split(",")[0]
    ?.trim();
  const networkAddress = request.headers.get("cf-connecting-ip")
    ?? forwardedFor
    ?? "unknown";
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
  const { data, error } = await admin.rpc("issue_score_run", {
    p_run_id: payload.run_id,
    p_token_hash: await sha256(token),
    p_rate_key: await digestNetworkKey(
      `ticket:${networkAddress}`,
      serviceRoleKey,
    ),
  });
  if (error || !data?.length) {
    if (
      error?.code === "P0001"
      && error.message === "run_ticket_rate_limit_exceeded"
    ) {
      return json(
        { error: "Too many new runs. Try again later." },
        429,
        origin,
      );
    }
    if (["22023", "22P02"].includes(error?.code ?? "")) {
      return json(
        { error: error?.message ?? "Run request is invalid." },
        400,
        origin,
      );
    }
    console.error("Run ticket creation failed.", error);
    return json({ error: "Run could not be registered." }, 500, origin);
  }

  return json({
    run_id: payload.run_id,
    run_token: token,
    expires_at: data[0].expires_at,
  }, 201, origin);
});
