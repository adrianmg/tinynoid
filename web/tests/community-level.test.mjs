import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  LEVEL_SCHEMA,
  canonicalText,
  contentHash,
  emptyLayout,
  isCommunityLevelId,
  normalizeName,
  resolvePaintCode,
  validateLevel,
} from "../editor/community-level.js";

const canonicalSchema = JSON.parse(
  await readFile(
    new URL("../../schema/community-level-v1.schema.json", import.meta.url),
    "utf8",
  ),
);

function validLevel(overrides = {}) {
  const layout = emptyLayout();
  layout[0] = "RRRRRRRR.....";
  return {
    schema_version: 1,
    level_name: "NEON RUN",
    creator_display_name: "@BUILDER",
    layout,
    ...overrides,
  };
}

test("normalizes public names deterministically", () => {
  assert.equal(normalizeName("  neon   run  "), "NEON RUN");
  assert.equal(normalizeName("@builder_01"), "@BUILDER_01");
});

test("matches the repository canonical schema", () => {
  assert.equal(canonicalSchema.properties.schema_version.const, LEVEL_SCHEMA.schemaVersion);
  assert.equal(canonicalSchema["x-tinynoid"].columns, LEVEL_SCHEMA.columns);
  assert.equal(canonicalSchema["x-tinynoid"].rows, LEVEL_SCHEMA.rows);
  assert.deepEqual(canonicalSchema["x-tinynoid"].allowed_cell_codes, LEVEL_SCHEMA.codes);
  assert.equal(
    canonicalSchema["x-tinynoid"].minimum_destructible_cells,
    LEVEL_SCHEMA.minDestructible,
  );
  assert.equal(
    canonicalSchema["x-tinynoid"].maximum_populated_cells,
    LEVEL_SCHEMA.maxPopulated,
  );
});

test("accepts the canonical 13 by 10 layout", () => {
  const result = validateLevel(validLevel());
  assert.equal(result.valid, true);
  assert.equal(result.counts.populated, 8);
  assert.equal(result.counts.destructible, 8);
  assert.deepEqual(result.normalized.layout, validLevel().layout);
});

test("rejects malformed dimensions and unsupported cells", () => {
  assert.match(
    validateLevel(validLevel({ layout: ["RRRRRRRR....."] })).errors.layout,
    /10 rows/,
  );
  const layout = validLevel().layout;
  layout[1] = "......Z......";
  assert.match(validateLevel(validLevel({ layout })).errors.layout, /supported cells/);
});

test("rejects unsafe names and unplayable density", () => {
  const sparse = emptyLayout();
  sparse[0] = "XXXXXXXR.....";
  const result = validateLevel(
    validLevel({
      level_name: "<SCRIPT>",
      creator_display_name: "A",
      layout: sparse,
    }),
  );
  assert.match(result.errors.level_name, /may use/);
  assert.match(result.errors.creator_display_name, /at least 2/);
  assert.match(result.errors.layout, /8 breakable/);
});

test("rejects more than 100 populated cells", () => {
  const layout = Array.from({ length: LEVEL_SCHEMA.rows }, () => "RRRRRRRRRRRRR");
  assert.match(validateLevel(validLevel({ layout })).errors.layout, /no more than 100/);
});

test("hashes normalized canonical text deterministically", async () => {
  const result = validateLevel(
    validLevel({ level_name: " neon   run ", creator_display_name: " @builder " }),
  );
  assert.equal(
    canonicalText(result.normalized),
    ["1", "NEON RUN", "@BUILDER", ...result.normalized.layout].join("\n"),
  );
  assert.equal(
    await contentHash(result.normalized),
    "c52e572b79b7fcb14970bdc09bea51548e45b4df866066df14a68f448542b8e0",
  );
});

test("recognizes only canonical public ids", () => {
  assert.equal(isCommunityLevelId("cl_6c4e88e29b91f4d2f386647f"), true);
  assert.equal(isCommunityLevelId("CL_6c4e88e29b91f4d2f386647f"), false);
  assert.equal(isCommunityLevelId("cl_short"), false);
});

test("resolves selected, cycling, and erase paint tools", () => {
  assert.equal(resolvePaintCode("R", ".", false), "R");
  assert.equal(resolvePaintCode("cycle", "R", false), "B");
  assert.equal(resolvePaintCode("cycle", "X", false), ".");
  assert.equal(resolvePaintCode("Y", "R", true), ".");
  assert.equal(resolvePaintCode("invalid", "G", false), "G");
});
