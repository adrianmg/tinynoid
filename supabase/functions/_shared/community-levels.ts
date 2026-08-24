export const SCHEMA_VERSION = 1;
export const MAX_BODY_BYTES = 4096;
export const CATALOG_DEFAULT_LIMIT = 50;
export const CATALOG_MAX_LIMIT = 100;

const NAME_PATTERN = /^[A-Z0-9 @._-]+$/;
const ROW_PATTERN = /^[.WOCGRBPYSX]{13}$/;
const PUBLIC_ID_PATTERN = /^cl_[0-9a-f]{24}$/;
const encoder = new TextEncoder();

export class RequestValidationError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status = 400,
  ) {
    super(message);
    this.name = "RequestValidationError";
  }
}

export interface CommunityLevelDocument {
  schema_version: 1;
  level_name: string;
  creator_display_name: string;
  layout: string[];
}

export interface CanonicalCommunityLevel extends CommunityLevelDocument {
  canonical_text: string;
}

export interface SubmissionResult {
  id: string;
  created: boolean;
  status: "pending" | "listed";
}

export function normalizeName(
  value: unknown,
  field: "level_name" | "creator_display_name",
  minimum: number,
  maximum: number,
): string {
  if (typeof value !== "string") {
    throw new RequestValidationError(
      "invalid_request",
      `${field} must be a string.`,
    );
  }

  const normalized = value.trim().replace(/\s+/gu, " ").toUpperCase();
  if (normalized.length < minimum || normalized.length > maximum) {
    throw new RequestValidationError(
      "invalid_request",
      `${field} must contain ${minimum} to ${maximum} characters.`,
    );
  }
  if (!NAME_PATTERN.test(normalized)) {
    throw new RequestValidationError(
      "invalid_request",
      `${field} contains unsupported characters.`,
    );
  }
  return normalized;
}

export function validateLayout(value: unknown): string[] {
  if (!Array.isArray(value) || value.length !== 10) {
    throw new RequestValidationError(
      "invalid_request",
      "layout must contain exactly 10 rows.",
    );
  }

  let destructibleCells = 0;
  let populatedCells = 0;
  for (const row of value) {
    if (typeof row !== "string" || !ROW_PATTERN.test(row)) {
      throw new RequestValidationError(
        "invalid_request",
        "Each layout row must contain exactly 13 supported ASCII brick codes.",
      );
    }
    for (const code of row) {
      if (code !== ".") {
        populatedCells++;
      }
      if (code !== "." && code !== "X") {
        destructibleCells++;
      }
    }
  }

  if (destructibleCells < 8) {
    throw new RequestValidationError(
      "invalid_request",
      "layout must contain at least 8 destructible cells.",
    );
  }
  if (populatedCells > 100) {
    throw new RequestValidationError(
      "invalid_request",
      "layout must contain at most 100 populated cells.",
    );
  }
  return [...value];
}

export function canonicalizeSubmission(
  value: unknown,
): CanonicalCommunityLevel {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new RequestValidationError(
      "invalid_request",
      "Request body must be a JSON object.",
    );
  }

  const payload = value as Record<string, unknown>;
  const expectedKeys = [
    "creator_display_name",
    "layout",
    "level_name",
    "schema_version",
  ];
  const actualKeys = Object.keys(payload).sort();
  if (
    actualKeys.length !== expectedKeys.length ||
    actualKeys.some((key, index) => key !== expectedKeys[index])
  ) {
    throw new RequestValidationError(
      "invalid_request",
      "Request body contains missing or unsupported fields.",
    );
  }
  if (payload.schema_version !== SCHEMA_VERSION) {
    throw new RequestValidationError(
      "invalid_request",
      "schema_version must be 1.",
    );
  }

  const levelName = normalizeName(payload.level_name, "level_name", 2, 32);
  const creatorName = normalizeName(
    payload.creator_display_name,
    "creator_display_name",
    2,
    24,
  );
  const layout = validateLayout(payload.layout);
  const canonicalText = [
    String(SCHEMA_VERSION),
    levelName,
    creatorName,
    ...layout,
  ].join("\n");

  return {
    schema_version: SCHEMA_VERSION,
    level_name: levelName,
    creator_display_name: creatorName,
    layout,
    canonical_text: canonicalText,
  };
}

function bytesToHex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function hashCanonicalText(canonicalText: string): Promise<{
  contentHash: string;
  publicId: string;
}> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    encoder.encode(canonicalText),
  );
  const contentHash = bytesToHex(digest);
  return {
    contentHash,
    publicId: `cl_${contentHash.slice(0, 24)}`,
  };
}

export async function digestNetworkIdentifier(
  identifier: string,
  secret: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return bytesToHex(
    await crypto.subtle.sign("HMAC", key, encoder.encode(identifier)),
  );
}

export function networkIdentifier(request: Request): string {
  const forwardedFor = request.headers.get("x-forwarded-for")
    ?.split(",", 1)[0]
    ?.trim();
  return request.headers.get("cf-connecting-ip")?.trim() ||
    request.headers.get("x-real-ip")?.trim() ||
    forwardedFor ||
    "unknown";
}

export async function readJsonBody(request: Request): Promise<unknown> {
  const contentType = request.headers.get("content-type")?.trim() ?? "";
  if (!/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(contentType)) {
    throw new RequestValidationError(
      "unsupported_media_type",
      "Content-Type must be application/json.",
      415,
    );
  }

  const contentLength = request.headers.get("content-length");
  if (contentLength !== null) {
    if (
      !/^\d+$/.test(contentLength) || Number(contentLength) > MAX_BODY_BYTES
    ) {
      throw new RequestValidationError(
        "body_too_large",
        `Request body must not exceed ${MAX_BODY_BYTES} bytes.`,
        413,
      );
    }
  }

  const chunks: Uint8Array[] = [];
  let byteLength = 0;
  const reader = request.body?.getReader();
  if (reader) {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      byteLength += value.byteLength;
      if (byteLength > MAX_BODY_BYTES) {
        await reader.cancel();
        throw new RequestValidationError(
          "body_too_large",
          `Request body must not exceed ${MAX_BODY_BYTES} bytes.`,
          413,
        );
      }
      chunks.push(value);
    }
  }

  const bytes = new Uint8Array(byteLength);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  let bodyText: string;
  try {
    bodyText = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch (error) {
    if (error instanceof TypeError) {
      throw new RequestValidationError(
        "invalid_json",
        "Request body must be valid UTF-8 JSON.",
      );
    }
    throw error;
  }

  try {
    return JSON.parse(bodyText);
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new RequestValidationError(
        "invalid_json",
        "Request body must be valid JSON.",
      );
    }
    throw error;
  }
}

export function parseCatalogQuery(url: URL): {
  id: string | null;
  limit: number;
} {
  for (const key of url.searchParams.keys()) {
    if (key !== "id" && key !== "limit") {
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
  if (id !== null && !PUBLIC_ID_PATTERN.test(id)) {
    throw new RequestValidationError(
      "invalid_query",
      "id must be a valid community level id.",
    );
  }

  const limitValue = url.searchParams.get("limit");
  if (limitValue === null) {
    return { id, limit: id === null ? CATALOG_DEFAULT_LIMIT : 1 };
  }
  if (!/^\d+$/.test(limitValue)) {
    throw new RequestValidationError(
      "invalid_query",
      `limit must be between 1 and ${CATALOG_MAX_LIMIT}.`,
    );
  }
  const limit = Number(limitValue);
  if (limit < 1 || limit > CATALOG_MAX_LIMIT) {
    throw new RequestValidationError(
      "invalid_query",
      `limit must be between 1 and ${CATALOG_MAX_LIMIT}.`,
    );
  }
  return { id, limit: id === null ? limit : 1 };
}

export function submissionResult(
  row: Record<string, unknown> | undefined,
  expectedId: string,
): SubmissionResult {
  if (
    !row ||
    row.level_id !== expectedId ||
    typeof row.created !== "boolean" ||
    (row.status !== "pending" && row.status !== "listed")
  ) {
    throw new Error("Submission RPC returned an invalid result.");
  }
  return {
    id: expectedId,
    created: row.created,
    status: row.status,
  };
}
