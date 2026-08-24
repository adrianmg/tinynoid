import {
  canonicalizeSubmission,
  hashCanonicalText,
  parseCatalogQuery,
  readJsonBody,
  RequestValidationError,
  submissionResult,
  validateLayout,
} from "./community-levels.ts";

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

function assertValidationError(
  callback: () => unknown,
  expectedCode = "invalid_request",
): void {
  try {
    callback();
  } catch (error) {
    assert(error instanceof RequestValidationError);
    assertEquals(error.code, expectedCode);
    return;
  }
  throw new Error("Expected validation to fail.");
}

const VALID_LAYOUT = [
  "WOCGRBPYSX...",
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

Deno.test("canonicalizes names and builds the exact version 1 text", () => {
  const result = canonicalizeSubmission({
    schema_version: 1,
    level_name: "  tiny\t  challenge ",
    creator_display_name: " ada   7 ",
    layout: VALID_LAYOUT,
  });

  assertEquals(result.level_name, "TINY CHALLENGE");
  assertEquals(result.creator_display_name, "ADA 7");
  assertEquals(
    result.canonical_text,
    `1\nTINY CHALLENGE\nADA 7\n${VALID_LAYOUT.join("\n")}`,
  );
});

Deno.test("validates fixed dimensions, codes, and brick bounds", () => {
  assertEquals(validateLayout(VALID_LAYOUT), VALID_LAYOUT);
  assertEquals(
    validateLayout([
      "WWWWWWWW.....",
      ...VALID_LAYOUT.slice(1),
    ]),
    ["WWWWWWWW.....", ...VALID_LAYOUT.slice(1)],
  );
  assertValidationError(() => validateLayout(VALID_LAYOUT.slice(0, 9)));
  assertValidationError(() =>
    validateLayout(["WOCGRBPYSQ...", ...VALID_LAYOUT.slice(1)])
  );
  assertValidationError(() =>
    validateLayout([
      "WWWWWWW......",
      ...VALID_LAYOUT.slice(1),
    ])
  );

  const overfilled = [
    ..."WWWWWWWWWWWWW".repeat(7).match(/.{13}/g)!,
    "WWWWWWWWWW...",
    ".............",
    ".............",
  ];
  const exactlyFullEnough = [
    ..."WWWWWWWWWWWWW".repeat(7).match(/.{13}/g)!,
    "WWWWWWWWW....",
    ".............",
    ".............",
  ];
  assertEquals(validateLayout(exactlyFullEnough), exactlyFullEnough);
  assertValidationError(() => validateLayout(overfilled));
});

Deno.test("rejects unsupported names and noncanonical request fields", () => {
  assertValidationError(() =>
    canonicalizeSubmission({
      schema_version: 1,
      level_name: "A!",
      creator_display_name: "ADA",
      layout: VALID_LAYOUT,
    })
  );
  assertValidationError(() =>
    canonicalizeSubmission({
      schema_version: 1,
      level_name: "OK",
      creator_display_name: "ADA",
      layout: VALID_LAYOUT,
      unexpected: true,
    })
  );
});

Deno.test("hashes canonical UTF-8 text into a stable lowercase id", async () => {
  const canonical = canonicalizeSubmission({
    schema_version: 1,
    level_name: "TINY CHALLENGE",
    creator_display_name: "ADA 7",
    layout: VALID_LAYOUT,
  });
  const result = await hashCanonicalText(canonical.canonical_text);

  assertEquals(
    result.contentHash,
    "dae8d3c688b8ba0a8a6904fa9b83415c5e231ae5924db32dbe7945117f75890d",
  );
  assertEquals(result.publicId, "cl_dae8d3c688b8ba0a8a6904fa");
});

Deno.test("maps duplicate-facing RPC rows without changing the public id", () => {
  assertEquals(
    submissionResult(
      {
        level_id: "cl_dae8d3c688b8ba0a8a6904fa",
        created: false,
        status: "pending",
      },
      "cl_dae8d3c688b8ba0a8a6904fa",
    ),
    {
      id: "cl_dae8d3c688b8ba0a8a6904fa",
      created: false,
      status: "pending",
    },
  );
});

Deno.test("preserves listed status for an existing public level", () => {
  assertEquals(
    submissionResult(
      {
        level_id: "cl_dae8d3c688b8ba0a8a6904fa",
        created: false,
        status: "listed",
      },
      "cl_dae8d3c688b8ba0a8a6904fa",
    ),
    {
      id: "cl_dae8d3c688b8ba0a8a6904fa",
      created: false,
      status: "listed",
    },
  );
});

Deno.test("enforces the real streamed body size without content-length", async () => {
  const request = new Request("http://localhost/submit-level", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: new ReadableStream({
      start(controller) {
        controller.enqueue(new Uint8Array(4097));
        controller.close();
      },
    }),
  });

  try {
    await readJsonBody(request);
  } catch (error) {
    assert(error instanceof RequestValidationError);
    assertEquals(error.code, "body_too_large");
    assertEquals(error.status, 413);
    return;
  }
  throw new Error("Expected oversized body to fail.");
});

Deno.test("bounds catalog queries and supports exact ids", () => {
  assertEquals(
    parseCatalogQuery(
      new URL(
        "https://example.test/community-levels?id=cl_be606f972fe6a3edec03dca4",
      ),
    ),
    { id: "cl_be606f972fe6a3edec03dca4", limit: 1 },
  );
  assertValidationError(
    () =>
      parseCatalogQuery(
        new URL("https://example.test/community-levels?limit=101"),
      ),
    "invalid_query",
  );
});
