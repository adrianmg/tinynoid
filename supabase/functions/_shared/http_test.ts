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

Deno.test("origin allowlist accepts only Wavedash build subdomains", () => {
  const build = "mx7751qbsffxsd8wgxew4p086d84j0de-1a2b3c4d-9f8e7d6c";
  assert(isAllowedOrigin(`https://${build}.builds.wavedashcdn.com`));
  assert(!isAllowedOrigin(`http://${build}.builds.wavedashcdn.com`));
  assert(!isAllowedOrigin(`https://${build}.builds.wavedashcdn.com:8443`));
  assert(
    !isAllowedOrigin(`https://${build}.builds.wavedashcdn.com.evil.example`),
  );
  assert(!isAllowedOrigin(`https://evil.${build}.builds.wavedashcdn.com`));
  assert(!isAllowedOrigin("https://game-xyz-9f8e7d6c.builds.wavedashcdn.com"));
  assert(!isAllowedOrigin("https://ugc.wavedashcdn.com"));
  assert(!isAllowedOrigin("https://wavedashcdn.com"));
  assert(!isAllowedOrigin("https://wavedash.com"));
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
