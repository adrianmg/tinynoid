export const LEVEL_SCHEMA = Object.freeze({
  schemaVersion: 1,
  columns: 13,
  rows: 10,
  empty: ".",
  codes: Object.freeze([".", "W", "O", "C", "G", "R", "B", "P", "Y", "S", "X"]),
  minDestructible: 8,
  maxPopulated: 100,
  maxPayloadBytes: 4096,
  levelName: Object.freeze({ min: 2, max: 32 }),
  creatorName: Object.freeze({ min: 2, max: 24 }),
});

export const GAME_URL = "https://tinynoid.vercel.app/";

const NAME_PATTERN = /^[A-Z0-9 @._-]+$/;
const ID_PATTERN = /^cl_[0-9a-f]{24}$/;
export function normalizeName(value) {
  return String(value ?? "").trim().replace(/\s+/g, " ").toUpperCase();
}

export function emptyLayout() {
  return Array.from(
    { length: LEVEL_SCHEMA.rows },
    () => LEVEL_SCHEMA.empty.repeat(LEVEL_SCHEMA.columns),
  );
}

export function resolvePaintCode(tool, currentCode, erase = false) {
  if (erase || tool === LEVEL_SCHEMA.empty) {
    return LEVEL_SCHEMA.empty;
  }
  if (tool === "cycle") {
    const index = LEVEL_SCHEMA.codes.indexOf(currentCode);
    return LEVEL_SCHEMA.codes[(index + 1) % LEVEL_SCHEMA.codes.length];
  }
  return LEVEL_SCHEMA.codes.includes(tool) ? tool : currentCode;
}

export function interpolateGridIndexes(startIndex, endIndex) {
  const cellCount = LEVEL_SCHEMA.columns * LEVEL_SCHEMA.rows;
  if (
    !Number.isInteger(startIndex) ||
    !Number.isInteger(endIndex) ||
    startIndex < 0 ||
    endIndex < 0 ||
    startIndex >= cellCount ||
    endIndex >= cellCount
  ) {
    return [];
  }

  const startRow = Math.floor(startIndex / LEVEL_SCHEMA.columns);
  const startColumn = startIndex % LEVEL_SCHEMA.columns;
  const endRow = Math.floor(endIndex / LEVEL_SCHEMA.columns);
  const endColumn = endIndex % LEVEL_SCHEMA.columns;
  const rowDistance = endRow - startRow;
  const columnDistance = endColumn - startColumn;
  const steps = Math.max(Math.abs(rowDistance), Math.abs(columnDistance));
  if (steps === 0) return [startIndex];

  const indexes = [];
  for (let step = 0; step <= steps; step += 1) {
    const row = Math.round(startRow + (rowDistance * step) / steps);
    const column = Math.round(startColumn + (columnDistance * step) / steps);
    const index = row * LEVEL_SCHEMA.columns + column;
    if (indexes.at(-1) !== index) indexes.push(index);
  }
  return indexes;
}

export function gridNavigationTarget(index, key) {
  const cellCount = LEVEL_SCHEMA.columns * LEVEL_SCHEMA.rows;
  if (
    !Number.isInteger(index) ||
    index < 0 ||
    index >= cellCount
  ) {
    return null;
  }

  const row = Math.floor(index / LEVEL_SCHEMA.columns);
  const column = index % LEVEL_SCHEMA.columns;
  if (key === "ArrowLeft") return column > 0 ? index - 1 : index;
  if (key === "ArrowRight") {
    return column < LEVEL_SCHEMA.columns - 1 ? index + 1 : index;
  }
  if (key === "ArrowUp") return row > 0 ? index - LEVEL_SCHEMA.columns : index;
  if (key === "ArrowDown") {
    return row < LEVEL_SCHEMA.rows - 1 ? index + LEVEL_SCHEMA.columns : index;
  }
  return null;
}

export function countLayout(layout) {
  let populated = 0;
  let destructible = 0;

  for (const row of layout) {
    for (const code of row) {
      if (code !== LEVEL_SCHEMA.empty) {
        populated += 1;
      }
      if (code !== LEVEL_SCHEMA.empty && code !== "X") {
        destructible += 1;
      }
    }
  }

  return { populated, destructible };
}

function validateDisplayName(value, limits, label) {
  if (value.length < limits.min) {
    return `${label} needs at least ${limits.min} characters.`;
  }
  if (value.length > limits.max) {
    return `${label} must be ${limits.max} characters or fewer.`;
  }
  if (!NAME_PATTERN.test(value)) {
    return `${label} may use A-Z, 0-9, spaces, @, ., _, and -.`;
  }
  return "";
}

export function validateLevel(input) {
  const levelName = normalizeName(input?.level_name);
  const creatorName = normalizeName(input?.creator_display_name);
  const layout = Array.isArray(input?.layout) ? input.layout : [];
  const errors = {
    level_name: validateDisplayName(
      levelName,
      LEVEL_SCHEMA.levelName,
      "Level name",
    ),
    creator_display_name: validateDisplayName(
      creatorName,
      LEVEL_SCHEMA.creatorName,
      "Creator name",
    ),
    layout: "",
  };

  if (input?.schema_version !== LEVEL_SCHEMA.schemaVersion) {
    errors.layout = "This editor only submits schema version 1.";
  } else if (layout.length !== LEVEL_SCHEMA.rows) {
    errors.layout = `Layout must contain ${LEVEL_SCHEMA.rows} rows.`;
  } else {
    const invalidRow = layout.find(
      (row) =>
        typeof row !== "string" ||
        row.length !== LEVEL_SCHEMA.columns ||
        [...row].some((code) => !LEVEL_SCHEMA.codes.includes(code)),
    );
    if (invalidRow !== undefined) {
      errors.layout =
        `Every row must contain ${LEVEL_SCHEMA.columns} supported cells.`;
    }
  }

  let counts = { populated: 0, destructible: 0 };
  if (!errors.layout) {
    counts = countLayout(layout);
    if (counts.destructible < LEVEL_SCHEMA.minDestructible) {
      errors.layout =
        `Add at least ${LEVEL_SCHEMA.minDestructible} breakable bricks.`;
    } else if (counts.populated > LEVEL_SCHEMA.maxPopulated) {
      errors.layout = `Use no more than ${LEVEL_SCHEMA.maxPopulated} bricks.`;
    }
  }

  const normalized = {
    schema_version: LEVEL_SCHEMA.schemaVersion,
    level_name: levelName,
    creator_display_name: creatorName,
    layout: [...layout],
  };
  const payloadBytes =
    new TextEncoder().encode(JSON.stringify(normalized)).length;
  if (payloadBytes > LEVEL_SCHEMA.maxPayloadBytes && !errors.layout) {
    errors.layout = `Submission exceeds ${LEVEL_SCHEMA.maxPayloadBytes} bytes.`;
  }

  return {
    valid: !Object.values(errors).some(Boolean),
    errors,
    normalized,
    counts,
    payloadBytes,
  };
}

export function canonicalText(level) {
  return [
    String(LEVEL_SCHEMA.schemaVersion),
    level.level_name,
    level.creator_display_name,
    ...level.layout,
  ].join("\n");
}

export async function contentHash(level) {
  const bytes = new TextEncoder().encode(canonicalText(level));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function isCommunityLevelId(value) {
  return ID_PATTERN.test(String(value ?? ""));
}

export function communityLevelUrl(levelId, gameUrl = GAME_URL) {
  if (!isCommunityLevelId(levelId)) return "";
  const url = new URL(gameUrl);
  url.search = "";
  url.hash = "";
  url.searchParams.set("community", levelId);
  return url.href;
}

export function communityLevelFallbackUrl(
  levelId,
  shareUrl = GAME_URL,
) {
  if (!isCommunityLevelId(levelId)) return "";
  return new URL(`level/${levelId}`, shareUrl).href;
}
