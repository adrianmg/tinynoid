const ALLOWED_WEB_ORIGINS = new Set([
  "https://adrianmg.github.io",
]);
const LOCAL_ORIGIN = /^http:\/\/(?:localhost|127\.0\.0\.1)(?::\d+)?$/;

export interface ErrorBody {
  error: {
    code: string;
    message: string;
  };
}

export function isAllowedOrigin(origin: string | null): boolean {
  return origin === null ||
    ALLOWED_WEB_ORIGINS.has(origin) ||
    (origin !== null && LOCAL_ORIGIN.test(origin));
}

export function corsHeaders(
  origin: string | null,
  methods: string,
): Headers {
  const headers = new Headers({
    "Access-Control-Allow-Headers": "apikey, content-type",
    "Access-Control-Allow-Methods": methods,
    "Cache-Control": "no-store",
    "Content-Type": "application/json; charset=utf-8",
    "Vary": "Origin",
  });
  headers.set("Access-Control-Allow-Origin", origin ?? "*");
  return headers;
}

export function jsonResponse(
  body: unknown,
  status: number,
  origin: string | null,
  methods: string,
  extraHeaders?: HeadersInit,
): Response {
  const headers = corsHeaders(origin, methods);
  if (extraHeaders) {
    new Headers(extraHeaders).forEach((value, key) => headers.set(key, value));
  }
  return new Response(JSON.stringify(body), { status, headers });
}

export function errorResponse(
  code: string,
  message: string,
  status: number,
  origin: string | null,
  methods: string,
  extraHeaders?: HeadersInit,
): Response {
  const body: ErrorBody = { error: { code, message } };
  return jsonResponse(body, status, origin, methods, extraHeaders);
}

export function rejectedOriginResponse(methods: string): Response {
  return new Response(
    JSON.stringify(
      {
        error: {
          code: "origin_not_allowed",
          message: "Origin is not allowed.",
        },
      } satisfies ErrorBody,
    ),
    {
      status: 403,
      headers: {
        "Access-Control-Allow-Methods": methods,
        "Cache-Control": "no-store",
        "Content-Type": "application/json; charset=utf-8",
        "Vary": "Origin",
      },
    },
  );
}

export function rateLimitResponse(
  origin: string | null,
  retryAfterSeconds: number,
  methods = "POST, OPTIONS",
): Response {
  return errorResponse(
    "rate_limit_exceeded",
    "Too many level submissions. Try again later.",
    429,
    origin,
    methods,
    { "Retry-After": String(Math.max(1, Math.ceil(retryAfterSeconds))) },
  );
}
