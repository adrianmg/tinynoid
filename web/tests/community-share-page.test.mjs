import assert from "node:assert/strict";
import test from "node:test";
import {
  communityImageUrl,
  communityPlayUrl,
  communitySharePage,
  communityShareUrl,
  formatCreatorName,
  parseCommunityLevel,
} from "../../tinynoid-share/lib/community-share.js";

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

test("builds community play and image URLs", () => {
  assert.equal(
    communityPlayUrl(LEVEL_ID),
    `https://tinynoid.vercel.app/?community=${LEVEL_ID}`,
  );
  assert.equal(
    communityImageUrl(LEVEL),
    `https://ugkygoijpqrreooylpnc.supabase.co/functions/v1/share-level?id=${LEVEL_ID}&image=1`,
  );
});

test("formats community creators with exactly one at sign", () => {
  assert.equal(formatCreatorName("adrianmg"), "@ADRIANMG");
  assert.equal(formatCreatorName("@ADRIANMG"), "@ADRIANMG");
});

test("renders personalized HTML metadata before redirecting", () => {
  const shareUrl = "https://tinynoid.vercel.app/neon-test";
  const page = communitySharePage(LEVEL);
  assert.match(page, /NEON TEST - TINYNOID Community Level/);
  assert.match(page, /Play NEON TEST by @BUILDER in TINYNOID\./);
  assert.match(page, /twitter:card" content="summary_large_image/);
  assert.match(page, new RegExp(`og:url" content="${shareUrl}`));
  assert.match(page, new RegExp(`\\?community=${LEVEL_ID}`));
});

test("uses the database-resolved canonical slug", () => {
  assert.equal(
    communityShareUrl(LEVEL),
    "https://tinynoid.vercel.app/neon-test",
  );
});

test("rejects malformed community responses", () => {
  assert.throws(
    () => parseCommunityLevel({ ...LEVEL, status: "removed" }, LEVEL_ID),
    /invalid level/,
  );
});
