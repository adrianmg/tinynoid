import {
  isCommunityLevelId,
  RequestValidationError,
  validateLayout,
} from "./community-levels.ts";

const DAILY_ID_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HANDLE_PATTERN = /^@[A-Z0-9_]{1,15}$/;

export interface DailyLevel {
  id: string;
  schema_version: 1;
  level_name: string;
  creator_display_name: string;
  layout: string[];
  populated_count: number;
  created_at: string;
  status: "pending" | "listed";
}

export interface DailyCartridge {
  daily_id: string;
  opens_at: string;
  closes_at: string;
  accept_until: string;
  run_seed: number;
  max_score: number;
  level: DailyLevel;
}

function expectObject(
  value: unknown,
  expectedKeys: string[],
): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new RequestValidationError(
      "invalid_request",
      "Request body must be a JSON object.",
    );
  }
  const payload = value as Record<string, unknown>;
  const actualKeys = Object.keys(payload).sort();
  const sortedExpected = [...expectedKeys].sort();
  if (
    actualKeys.length !== sortedExpected.length ||
    actualKeys.some((key, index) => key !== sortedExpected[index])
  ) {
    throw new RequestValidationError(
      "invalid_request",
      "Request body contains missing or unsupported fields.",
    );
  }
  return payload;
}

export function parseDailyId(value: unknown): string {
  if (typeof value !== "string" || !DAILY_ID_PATTERN.test(value)) {
    throw new RequestValidationError(
      "invalid_request",
      "daily_id must use YYYY-MM-DD.",
    );
  }
  const parsed = new Date(`${value}T00:00:00Z`);
  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== value
  ) {
    throw new RequestValidationError(
      "invalid_request",
      "daily_id is not a valid UTC date.",
    );
  }
  return value;
}

export function parseRunId(value: unknown): string {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw new RequestValidationError(
      "invalid_request",
      "run_id must be a UUID.",
    );
  }
  return value.toLowerCase();
}

export function parseStartDailyRun(value: unknown): {
  run_id: string;
  daily_id: string;
} {
  const payload = expectObject(value, ["daily_id", "run_id"]);
  return {
    run_id: parseRunId(payload.run_id),
    daily_id: parseDailyId(payload.daily_id),
  };
}

export function parseSubmitDailyScore(value: unknown): {
  run_id: string;
  run_token: string;
  daily_id: string;
  level_id: string;
  player_name: string;
  score: number;
  outcome: "game_over" | "daily_clear";
} {
  const payload = expectObject(value, [
    "daily_id",
    "level_id",
    "outcome",
    "player_name",
    "run_id",
    "run_token",
    "score",
  ]);
  const playerName = String(payload.player_name ?? "").trim().toUpperCase();
  if (!HANDLE_PATTERN.test(playerName)) {
    throw new RequestValidationError(
      "invalid_request",
      "player_name must be an X handle.",
    );
  }
  if (!isCommunityLevelId(payload.level_id)) {
    throw new RequestValidationError(
      "invalid_request",
      "level_id is invalid.",
    );
  }
  if (
    typeof payload.score !== "number" ||
    !Number.isSafeInteger(payload.score) ||
    payload.score < 0
  ) {
    throw new RequestValidationError(
      "invalid_request",
      "score must be a non-negative integer.",
    );
  }
  if (payload.outcome !== "game_over" && payload.outcome !== "daily_clear") {
    throw new RequestValidationError(
      "invalid_request",
      "outcome is invalid.",
    );
  }
  if (
    typeof payload.run_token !== "string" ||
    !/^[0-9a-f]{64}$/.test(payload.run_token)
  ) {
    throw new RequestValidationError(
      "invalid_request",
      "run_token is invalid.",
    );
  }
  return {
    run_id: parseRunId(payload.run_id),
    run_token: payload.run_token,
    daily_id: parseDailyId(payload.daily_id),
    level_id: payload.level_id,
    player_name: playerName,
    score: payload.score,
    outcome: payload.outcome,
  };
}

export function parseDailyCartridgeRow(value: unknown): DailyCartridge {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new RequestValidationError(
      "invalid_response",
      "Daily cartridge response is invalid.",
      502,
    );
  }
  const row = value as Record<string, unknown>;
  const dailyId = parseDailyId(row.daily_id);
  if (
    !isCommunityLevelId(row.id) ||
    row.schema_version !== 1 ||
    typeof row.level_name !== "string" ||
    typeof row.creator_display_name !== "string" ||
    (row.status !== "pending" && row.status !== "listed") ||
    typeof row.populated_count !== "number" ||
    !Number.isSafeInteger(row.populated_count) ||
    typeof row.created_at !== "string" ||
    typeof row.opens_at !== "string" ||
    typeof row.closes_at !== "string" ||
    typeof row.accept_until !== "string" ||
    typeof row.run_seed !== "number" ||
    !Number.isSafeInteger(row.run_seed) ||
    row.run_seed < 0 ||
    typeof row.max_score !== "number" ||
    !Number.isSafeInteger(row.max_score) ||
    row.max_score < 0
  ) {
    throw new RequestValidationError(
      "invalid_response",
      "Daily cartridge response is invalid.",
      502,
    );
  }
  const layout = validateLayout(row.layout);
  const populatedCount = layout.reduce(
    (count, line) =>
      count + [...line].filter((character) => character !== ".").length,
    0,
  );
  if (populatedCount !== row.populated_count) {
    throw new RequestValidationError(
      "invalid_response",
      "Daily cartridge population is invalid.",
      502,
    );
  }
  return {
    daily_id: dailyId,
    opens_at: row.opens_at,
    closes_at: row.closes_at,
    accept_until: row.accept_until,
    run_seed: row.run_seed,
    max_score: row.max_score,
    level: {
      id: row.id,
      schema_version: 1,
      level_name: row.level_name,
      creator_display_name: row.creator_display_name,
      layout,
      populated_count: populatedCount,
      created_at: row.created_at,
      status: row.status,
    },
  };
}

export function parseDailyRankRows(
  value: unknown,
): Array<Record<string, unknown>> {
  if (!Array.isArray(value) || value.length > 100) {
    throw new RequestValidationError(
      "invalid_response",
      "Daily leaderboard response is invalid.",
      502,
    );
  }
  return value.map((row, index) => {
    if (
      row === null ||
      typeof row !== "object" ||
      Array.isArray(row)
    ) {
      throw new RequestValidationError(
        "invalid_response",
        "Daily leaderboard row is invalid.",
        502,
      );
    }
    const entry = row as Record<string, unknown>;
    const playerName = String(entry.player_name ?? "");
    const outcome = String(entry.outcome ?? "");
    if (
      !HANDLE_PATTERN.test(playerName) ||
      typeof entry.score !== "number" ||
      !Number.isSafeInteger(entry.score) ||
      entry.score < 0 ||
      (outcome !== "game_over" && outcome !== "daily_clear") ||
      typeof entry.submitted_at !== "string"
    ) {
      throw new RequestValidationError(
        "invalid_response",
        "Daily leaderboard row is invalid.",
        502,
      );
    }
    return {
      rank: Number(entry.rank ?? index + 1),
      player_name: playerName,
      score: entry.score,
      outcome,
      submitted_at: entry.submitted_at,
      competitor_count: Number(entry.competitor_count ?? value.length),
    };
  });
}
