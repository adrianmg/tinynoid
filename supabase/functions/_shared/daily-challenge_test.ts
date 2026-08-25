import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  parseDailyCartridgeRow,
  parseDailyId,
  parseStartDailyRun,
  parseSubmitDailyScore,
} from "./daily-challenge.ts";

const RUN_ID = "0198d71f-1ef3-7000-8000-000000000010";
const LEVEL_ID = "cl_0123456789abcdef01234567";

Deno.test("parses strict daily request documents", () => {
  assertEquals(
    parseStartDailyRun({ run_id: RUN_ID, daily_id: "2026-08-25" }),
    { run_id: RUN_ID, daily_id: "2026-08-25" },
  );
  assertEquals(
    parseSubmitDailyScore({
      run_id: RUN_ID,
      run_token: "a".repeat(64),
      daily_id: "2026-08-25",
      level_id: LEVEL_ID,
      player_name: "@player",
      score: 1234,
      outcome: "daily_clear",
    }).player_name,
    "@PLAYER",
  );
  assertThrows(() => parseDailyId("2026-02-31"));
  assertThrows(() =>
    parseStartDailyRun({
      run_id: RUN_ID,
      daily_id: "2026-08-25",
      extra: true,
    })
  );
});

Deno.test("parses a canonical daily cartridge", () => {
  const cartridge = parseDailyCartridgeRow({
    daily_id: "2026-08-25",
    opens_at: "2026-08-25T00:00:00Z",
    closes_at: "2026-08-26T00:00:00Z",
    accept_until: "2026-08-26T06:00:00Z",
    run_seed: 42,
    max_score: 900,
    id: LEVEL_ID,
    schema_version: 1,
    level_name: "DAILY TEST",
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
    populated_count: 8,
    created_at: "2026-08-24T20:00:00Z",
    status: "pending",
  });
  assertEquals(cartridge.daily_id, "2026-08-25");
  assertEquals(cartridge.level.id, LEVEL_ID);
  assertEquals(cartridge.run_seed, 42);
});
