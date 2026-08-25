import assert from "node:assert/strict";
import test from "node:test";
import {
  COMMUNITY_IMAGE_VERSION,
  communityImageUrl,
  communityPlayUrl,
  communitySharePage,
  communityShareUrl,
  formatCreatorName,
  parseCommunityLevel,
} from "../../tinynoid-share/lib/community-share.js";
import ogLevel, {
  createOgLevelHandler,
  handle as handleOgLevel,
} from "../../tinynoid-share/api/og-level.js";

const LEVEL_ID = "cl_0123456789abcdef01234567";
const LEVEL = parseCommunityLevel(
  {
    id: LEVEL_ID,
    schema_version: 1,
    level_name: "NEON TEST",
    creator_display_name: "@BUILDER",
    layout: [
      "RRRRRRRR.....",
      ".............",
      ".............",
      ".............",
      ".............",
      ".............",
      ".............",
      ".............",
      ".............",
      ".............",
    ],
    created_at: "2026-08-24T20:00:00Z",
    slug: "neon-test",
    status: "pending",
  },
  LEVEL_ID,
);
const IMAGE_QUERY =
  `id=${LEVEL_ID}&v=${COMMUNITY_IMAGE_VERSION}-pending`;

test("builds community play and image URLs", () => {
  assert.equal(
    communityPlayUrl(LEVEL_ID),
    `https://tinynoid.vercel.app/?community=${LEVEL_ID}`,
  );
  assert.equal(
    communityImageUrl(LEVEL),
    `https://tinynoid.vercel.app/og/level/${LEVEL_ID}.png?v=${COMMUNITY_IMAGE_VERSION}-pending`,
  );
});

test("formats community creators with exactly one at sign", () => {
  assert.equal(formatCreatorName("adrianmg"), "@ADRIANMG");
  assert.equal(formatCreatorName("@ADRIANMG"), "@ADRIANMG");
});

test("renders personalized HTML metadata before redirecting", () => {
  const shareUrl =
    `https://tinynoid.vercel.app/neon-test?v=${COMMUNITY_IMAGE_VERSION}-pending`;
  const page = communitySharePage(LEVEL);
  assert.match(page, /NEON TEST - TINYNOID Community Level/);
  assert.match(page, /Play NEON TEST by @BUILDER in TINYNOID\./);
  assert.match(page, /twitter:card" content="summary_large_image/);
  assert.ok(page.includes(`og:url" content="${shareUrl}"`));
  assert.match(page, new RegExp(`\\?community=${LEVEL_ID}`));
});

test("uses the database-resolved canonical slug", () => {
  assert.equal(
    communityShareUrl(LEVEL),
    "https://tinynoid.vercel.app/neon-test",
  );
  assert.equal(
    communityShareUrl(LEVEL, true),
    `https://tinynoid.vercel.app/neon-test?v=${COMMUNITY_IMAGE_VERSION}-pending`,
  );
});

test("buffers crawler images with fixed same-origin PNG metadata", async () => {
  const png = new Uint8Array(24);
  png.set([137, 80, 78, 71, 13, 10, 26, 10]);
  const view = new DataView(png.buffer);
  view.setUint32(16, 1200);
  view.setUint32(20, 630);
  let upstreamUrl = "";
  const response = await handleOgLevel(
    new Request(`https://tinynoid.vercel.app/api/og-level?${IMAGE_QUERY}`),
    async (url) => {
      upstreamUrl = String(url);
      return new Response(png, {
        headers: { "Content-Type": "image/png" },
      });
    },
    async () => LEVEL,
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("content-type"), "image/png");
  assert.equal(response.headers.get("content-length"), "24");
  assert.match(response.headers.get("cache-control"), /s-maxage=300/);
  assert.doesNotMatch(response.headers.get("cache-control"), /immutable/);
  assert.equal(new Uint8Array(await response.arrayBuffer()).length, 24);
  assert.equal(
    upstreamUrl,
    `https://ugkygoijpqrreooylpnc.supabase.co/functions/v1/share-level?id=${LEVEL_ID}&image=1`,
  );

  const headResponse = await handleOgLevel(
    new Request(
      `https://tinynoid.vercel.app/api/og-level?${IMAGE_QUERY}`,
      { method: "HEAD" },
    ),
    async () =>
      new Response(png, {
        headers: { "Content-Type": "image/png" },
      }),
    async () => LEVEL,
  );
  assert.equal(headResponse.headers.get("content-length"), "24");
  assert.equal((await headResponse.arrayBuffer()).byteLength, 0);
});

test("ignores the Vercel runtime context argument", async () => {
  const png = new Uint8Array(24);
  png.set([137, 80, 78, 71, 13, 10, 26, 10]);
  const view = new DataView(png.buffer);
  view.setUint32(16, 1200);
  view.setUint32(20, 630);
  const handler = createOgLevelHandler(
    async () =>
      new Response(png, {
        headers: { "Content-Type": "image/png; charset=binary" },
      }),
    async () => LEVEL,
  );
  const response = await handler.fetch(
    new Request(
      `https://tinynoid.vercel.app/api/og-level?${IMAGE_QUERY}`,
    ),
    { waitUntil() {} },
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("content-length"), "24");
  assert.equal(typeof ogLevel.fetch, "function");
});

test("rejects invalid community OG image responses", async () => {
  const invalidId = await handleOgLevel(
    new Request("https://tinynoid.vercel.app/api/og-level?id=invalid"),
  );
  assert.equal(invalidId.status, 400);

  const invalidImage = await handleOgLevel(
    new Request(`https://tinynoid.vercel.app/api/og-level?${IMAGE_QUERY}`),
    async () =>
      new Response("not a png", {
        headers: { "Content-Type": "text/plain" },
      }),
    async () => LEVEL,
  );
  assert.equal(invalidImage.status, 502);

  const wrongVersion = await handleOgLevel(
    new Request(
      `https://tinynoid.vercel.app/api/og-level?id=${LEVEL_ID}&v=${COMMUNITY_IMAGE_VERSION}-listed`,
    ),
    async () => {
      throw new Error("Wrong versions must not render.");
    },
    async () => LEVEL,
  );
  assert.equal(wrongVersion.status, 404);

  const extraQuery = await handleOgLevel(
    new Request(
      `https://tinynoid.vercel.app/api/og-level?${IMAGE_QUERY}&bust=1`,
    ),
  );
  assert.equal(extraQuery.status, 400);

  const duplicateVersion = await handleOgLevel(
    new Request(
      `https://tinynoid.vercel.app/api/og-level?${IMAGE_QUERY}&v=cache-bust`,
    ),
  );
  assert.equal(duplicateVersion.status, 400);

  const listedLevel = { ...LEVEL, status: "listed" };
  const priorStatusImage = await handleOgLevel(
    new Request(`https://tinynoid.vercel.app/api/og-level?${IMAGE_QUERY}`),
    async () =>
      new Response(
        new Uint8Array([
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          4,
          176,
          0,
          0,
          2,
          118,
        ]),
        { headers: { "Content-Type": "image/png" } },
      ),
    async () => listedLevel,
  );
  assert.equal(priorStatusImage.status, 200);
});

test("rejects malformed community responses", () => {
  assert.throws(
    () => parseCommunityLevel({ ...LEVEL, status: "removed" }, LEVEL_ID),
    /invalid level/,
  );
});
