import {
  isCommunityLevelId,
  normalizeName,
  RequestValidationError,
  SCHEMA_VERSION,
  validateLayout,
} from "./community-levels.ts";

export interface SharedCommunityLevel {
  id: string;
  schema_version: 1;
  level_name: string;
  creator_display_name: string;
  layout: string[];
  status: "pending" | "listed";
}

export function parseShareQuery(url: URL): {
  id: string;
  image: boolean;
} {
  for (const key of url.searchParams.keys()) {
    if (key !== "id" && key !== "image") {
      throw new RequestValidationError(
        "invalid_query",
        `Unsupported query parameter: ${key}.`,
      );
    }
    if (url.searchParams.getAll(key).length !== 1) {
      throw new RequestValidationError(
        "invalid_query",
        `Query parameter ${key} must appear once.`,
      );
    }
  }

  const id = url.searchParams.get("id");
  if (!isCommunityLevelId(id)) {
    throw new RequestValidationError(
      "invalid_query",
      "id must be a valid community level id.",
    );
  }
  const imageValue = url.searchParams.get("image");
  if (imageValue !== null && imageValue !== "1") {
    throw new RequestValidationError(
      "invalid_query",
      "image must be 1 when provided.",
    );
  }
  return { id, image: imageValue === "1" };
}

export function parseSharedLevel(
  value: unknown,
  expectedId: string,
): SharedCommunityLevel {
  if (
    value === null ||
    typeof value !== "object" ||
    Array.isArray(value)
  ) {
    throw new Error("Community share lookup returned an invalid level.");
  }
  const row = value as Record<string, unknown>;
  if (
    row.id !== expectedId ||
    row.schema_version !== SCHEMA_VERSION ||
    (row.status !== "pending" && row.status !== "listed")
  ) {
    throw new Error("Community share lookup returned an invalid level.");
  }
  const levelName = normalizeName(row.level_name, "level_name", 2, 32);
  const creatorName = normalizeName(
    row.creator_display_name,
    "creator_display_name",
    2,
    24,
  );
  const layout = validateLayout(row.layout);
  return {
    id: expectedId,
    schema_version: SCHEMA_VERSION,
    level_name: levelName,
    creator_display_name: creatorName,
    layout,
    status: row.status,
  };
}
