import { parseSharedLevel, parseShareQuery } from "./community-share.ts";

function assert(
  condition: unknown,
  message = "Assertion failed",
): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEquals(actual: unknown, expected: unknown): void {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  assert(
    actualJson === expectedJson,
    `Expected ${expectedJson}, received ${actualJson}`,
  );
}

const LEVEL_ID = "cl_0123456789abcdef01234567";
const LAYOUT = [
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
];
const LEVEL = parseSharedLevel(
  {
    id: LEVEL_ID,
    schema_version: 1,
    level_name: "NEON RUN",
    creator_display_name: "@BUILDER",
    layout: LAYOUT,
    status: "pending",
  },
  LEVEL_ID,
);

Deno.test("parses a canonical community share request", () => {
  assertEquals(
    parseShareQuery(
      new URL(
        `https://example.test/functions/v1/share-level?id=${LEVEL_ID}&image=1`,
      ),
    ),
    { id: LEVEL_ID, image: true },
  );
});

Deno.test("validates personalized share data", () => {
  assertEquals(LEVEL.level_name, "NEON RUN");
  assertEquals(LEVEL.creator_display_name, "@BUILDER");
  assertEquals(LEVEL.status, "pending");
});
