import {
  isAllowedOrigin,
  rateLimitResponse,
  rejectedOriginResponse,
} from "./http.ts";

function assert(
  condition: unknown,
  message = "Assertion failed",
): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

Deno.test("origin allowlist matches production and loopback development", () => {
  assert(isAllowedOrigin(null));
  assert(isAllowedOrigin("https://tinynoid.vercel.app"));
  assert(isAllowedOrigin("http://localhost:8000"));
  assert(isAllowedOrigin("http://127.0.0.1:5173"));
  assert(!isAllowedOrigin("https://tinynoid.vercel.app.evil.example"));
  assert(!isAllowedOrigin("http://localhost.evil.example"));
});

Deno.test("rate limit response has stable shape and retry metadata", async () => {
  const response = rateLimitResponse("https://tinynoid.vercel.app", 12.2);
  const body = await response.json();

  assert(response.status === 429);
  assert(response.headers.get("retry-after") === "13");
  assert(
    response.headers.get("access-control-allow-origin") ===
      "https://tinynoid.vercel.app",
  );
  assert(body.error.code === "rate_limit_exceeded");
});

Deno.test("rejected origins do not receive an allow-origin header", () => {
  const response = rejectedOriginResponse("GET, OPTIONS");
  assert(response.status === 403);
  assert(response.headers.get("access-control-allow-origin") === null);
});
