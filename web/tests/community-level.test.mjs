import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  canonicalText,
  communityLevelShareText,
  communityLevelUrl,
  contentHash,
  emptyLayout,
  gridNavigationTarget,
  interpolateGridIndexes,
  isCommunityLevelId,
  LEVEL_SCHEMA,
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

function pngDimensions(buffer) {
  assert.equal(buffer.subarray(1, 4).toString("ascii"), "PNG");
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  };
}

test("normalizes public names deterministically", () => {
  assert.equal(normalizeName("  neon   run  "), "NEON RUN");
  assert.equal(normalizeName("@builder_01"), "@BUILDER_01");
});

test("matches the repository canonical schema", () => {
  assert.equal(
    canonicalSchema.properties.schema_version.const,
    LEVEL_SCHEMA.schemaVersion,
  );
  assert.equal(canonicalSchema["x-tinynoid"].columns, LEVEL_SCHEMA.columns);
  assert.equal(canonicalSchema["x-tinynoid"].rows, LEVEL_SCHEMA.rows);
  assert.deepEqual(
    canonicalSchema["x-tinynoid"].allowed_cell_codes,
    LEVEL_SCHEMA.codes,
  );
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
  assert.match(
    validateLevel(validLevel({ layout })).errors.layout,
    /supported cells/,
  );
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
  const layout = Array.from(
    { length: LEVEL_SCHEMA.rows },
    () => "RRRRRRRRRRRRR",
  );
  assert.match(
    validateLevel(validLevel({ layout })).errors.layout,
    /no more than 100/,
  );
});

test("hashes normalized canonical text deterministically", async () => {
  const result = validateLevel(
    validLevel({
      level_name: " neon   run ",
      creator_display_name: " @builder ",
    }),
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

test("generates canonical community level deep links", () => {
  assert.equal(
    communityLevelUrl("cl_6c4e88e29b91f4d2f386647f"),
    "https://tinynoid.vercel.app/?community=cl_6c4e88e29b91f4d2f386647f",
  );
  assert.equal(
    communityLevelUrl(
      "cl_6c4e88e29b91f4d2f386647f",
      "https://example.com/game/?old=query#stage",
    ),
    "https://example.com/game/?community=cl_6c4e88e29b91f4d2f386647f",
  );
  assert.equal(communityLevelUrl("cl_short"), "");
});

test("embeds the community level URL in share text", () => {
  assert.equal(
    communityLevelShareText(
      "Neon Run",
      "https://tinynoid.vercel.app/neon-run",
    ),
    "Play NEON RUN, a TINYNOID community level.\n" +
      "https://tinynoid.vercel.app/neon-run\n\n" +
      "Create your own level https://tinynoid.vercel.app/editor/",
  );
  assert.equal(communityLevelShareText("NEON RUN", "not a URL"), "");
});

test("ships large social cards and matching metadata", async () => {
  const [gameImage, editorImage, gameShell, editorPage] = await Promise.all([
    readFile(new URL("../og-image.png", import.meta.url)),
    readFile(new URL("../editor/og-image.png", import.meta.url)),
    readFile(new URL("../../godot/web_shell.html", import.meta.url), "utf8"),
    readFile(new URL("../editor/index.html", import.meta.url), "utf8"),
  ]);
  assert.deepEqual(pngDimensions(gameImage), { width: 1200, height: 630 });
  assert.deepEqual(pngDimensions(editorImage), { width: 1200, height: 630 });
  assert.match(gameShell, /property="og:image"/);
  assert.match(
    gameShell,
    /TINYNOID &mdash; A TINY TRIBUTE ARKANOID TRIBUTE BY ADRIAN MATO/,
  );
  assert.match(gameShell, /name="twitter:card" content="summary_large_image"/);
  assert.match(gameShell, /tinynoid\.vercel\.app\/og-image\.png/);
  assert.match(editorPage, /property="og:image"/);
  assert.match(editorPage, /name="twitter:card" content="summary_large_image"/);
  assert.match(editorPage, /tinynoid\.vercel\.app\/editor\/og-image\.png/);
});

test("uses local pixel typography without the duplicate masthead status", async () => {
  const [editorPage, editorStyles, pixelFont, fontLicense] = await Promise.all([
    readFile(new URL("../editor/index.html", import.meta.url), "utf8"),
    readFile(new URL("../editor/styles.css", import.meta.url), "utf8"),
    readFile(
      new URL("../editor/fonts/PressStart2P-Regular.ttf", import.meta.url),
    ),
    readFile(new URL("../editor/fonts/OFL.txt", import.meta.url), "utf8"),
  ]);
  assert.doesNotMatch(editorPage, /class="lab-status"/);
  assert.match(editorPage, /Published levels are unranked and marked UNREVIEWED/);
  assert.match(editorStyles, /font-family: "Press Start 2P"/);
  assert.match(editorStyles, /--font-pixel: "Press Start 2P"/);
  assert.match(
    editorStyles,
    /\.palette\s*\{[^}]*grid-template-columns: repeat\(6,/s,
  );
  assert.ok(pixelFont.length > 100_000);
  assert.match(fontLicense, /SIL OPEN FONT LICENSE Version 1\.1/);
});

test("resolves selected, cycling, and erase paint tools", () => {
  assert.equal(resolvePaintCode("R", ".", false), "R");
  assert.equal(resolvePaintCode("cycle", "R", false), "B");
  assert.equal(resolvePaintCode("cycle", "X", false), ".");
  assert.equal(resolvePaintCode("Y", "R", true), ".");
  assert.equal(resolvePaintCode("invalid", "G", false), "G");
});

test("interpolates complete horizontal, vertical, and diagonal strokes", () => {
  assert.deepEqual(interpolateGridIndexes(0, 4), [0, 1, 2, 3, 4]);
  assert.deepEqual(interpolateGridIndexes(0, 39), [0, 13, 26, 39]);
  assert.deepEqual(interpolateGridIndexes(0, 42), [0, 14, 28, 42]);
  assert.deepEqual(interpolateGridIndexes(42, 0), [42, 28, 14, 0]);
  assert.deepEqual(interpolateGridIndexes(-1, 4), []);
  assert.equal(new Set(interpolateGridIndexes(0, 42)).size, 4);
});

test("moves within grid rows and columns without wrapping at boundaries", () => {
  assert.equal(gridNavigationTarget(0, "ArrowUp"), 0);
  assert.equal(gridNavigationTarget(117, "ArrowDown"), 117);
  assert.equal(gridNavigationTarget(13, "ArrowLeft"), 13);
  assert.equal(gridNavigationTarget(12, "ArrowRight"), 12);
  assert.equal(gridNavigationTarget(14, "ArrowLeft"), 13);
  assert.equal(gridNavigationTarget(14, "ArrowRight"), 15);
  assert.equal(gridNavigationTarget(14, "ArrowUp"), 1);
  assert.equal(gridNavigationTarget(14, "ArrowDown"), 27);
  assert.equal(gridNavigationTarget(14, "Enter"), null);
});
