import {
  LEVEL_SCHEMA,
  emptyLayout,
  isCommunityLevelId,
  resolvePaintCode,
  validateLevel,
} from "./community-level.js";

const API_BASE = "https://ugkygoijpqrreooylpnc.supabase.co/functions/v1";
const PUBLISHABLE_KEY = "sb_publishable_GMQxCnYtLe3qCkV1Nc3N2w_5JXyve-X";

const BRICKS = Object.freeze({
  ".": { name: "EMPTY", color: "#090a17", highlight: "#090a17", shadow: "#090a17" },
  W: { name: "WHITE", color: "#f7f4ff", highlight: "#ffffff", shadow: "#aab3d7" },
  O: { name: "ORANGE", color: "#ff8a3d", highlight: "#ffc36f", shadow: "#9d3f22" },
  C: { name: "CYAN", color: "#74ddff", highlight: "#d8f7ff", shadow: "#287fc4" },
  G: { name: "GREEN", color: "#56d46f", highlight: "#a8f2a4", shadow: "#237247" },
  R: { name: "RED", color: "#f15b68", highlight: "#ff9c9f", shadow: "#982f46" },
  B: { name: "BLUE", color: "#6d83f2", highlight: "#a9b9ff", shadow: "#3447a3" },
  P: { name: "PINK", color: "#c967e8", highlight: "#efadff", shadow: "#74378f" },
  Y: { name: "YELLOW", color: "#ffd84a", highlight: "#fff09b", shadow: "#9d7d18" },
  S: { name: "SILVER", color: "#aab3c8", highlight: "#f7f4ff", shadow: "#59627d" },
  X: { name: "GOLD", color: "#d7a72e", highlight: "#fff09b", shadow: "#795817" },
});

const elements = {
  form: document.querySelector("#level-form"),
  grid: document.querySelector("#level-grid"),
  palette: document.querySelector("#palette"),
  levelName: document.querySelector("#level-name"),
  creatorName: document.querySelector("#creator-name"),
  levelNameError: document.querySelector("#level-name-error"),
  creatorNameError: document.querySelector("#creator-name-error"),
  blockCount: document.querySelector("#block-count"),
  filledReadout: document.querySelector("#filled-readout"),
  validityReadout: document.querySelector("#validity-readout"),
  submitButton: document.querySelector("#submit-button"),
  clearButton: document.querySelector("#clear-button"),
  status: document.querySelector("#submission-status"),
};

let layout = emptyLayout();
let submitting = false;
let clearArmed = false;
let clearTimer = 0;
let selectedTool = "cycle";
let painting = false;
let strokeCode = LEVEL_SCHEMA.empty;
let paintedIndexes = new Set();

function valueAt(index) {
  const row = Math.floor(index / LEVEL_SCHEMA.columns);
  const column = index % LEVEL_SCHEMA.columns;
  return layout[row][column];
}

function setValueAt(index, value) {
  const row = Math.floor(index / LEVEL_SCHEMA.columns);
  const column = index % LEVEL_SCHEMA.columns;
  layout[row] =
    layout[row].slice(0, column) + value + layout[row].slice(column + 1);
}

function applyBrickStyle(cell, code) {
  const brick = BRICKS[code];
  cell.dataset.value = code === LEVEL_SCHEMA.empty ? "empty" : code;
  cell.style.setProperty("--brick-color", brick.color);
  cell.style.setProperty("--brick-highlight", brick.highlight);
  cell.style.setProperty("--brick-shadow", brick.shadow);
  const index = Number(cell.dataset.index);
  const row = Math.floor(index / LEVEL_SCHEMA.columns) + 1;
  const column = (index % LEVEL_SCHEMA.columns) + 1;
  const action =
    selectedTool === "cycle"
      ? `Cycle to ${BRICKS[resolvePaintCode("cycle", code)].name}`
      : selectedTool === LEVEL_SCHEMA.empty
        ? "Erase"
        : `Paint ${BRICKS[selectedTool].name}`;
  cell.setAttribute(
    "aria-label",
    `Row ${row}, column ${column}: ${brick.name}. ${action}. Shift to erase.`,
  );
}

function renderGrid() {
  elements.grid.style.setProperty("--grid-columns", LEVEL_SCHEMA.columns);
  elements.grid.setAttribute("aria-rowcount", String(LEVEL_SCHEMA.rows));
  elements.grid.setAttribute("aria-colcount", String(LEVEL_SCHEMA.columns));
  elements.grid.replaceChildren();
  const fragment = document.createDocumentFragment();

  for (let index = 0; index < LEVEL_SCHEMA.rows * LEVEL_SCHEMA.columns; index += 1) {
    const cell = document.createElement("button");
    cell.type = "button";
    cell.className = "grid-cell";
    cell.dataset.index = String(index);
    cell.tabIndex = index === 0 ? 0 : -1;
    cell.setAttribute("role", "gridcell");
    cell.setAttribute("aria-rowindex", String(Math.floor(index / LEVEL_SCHEMA.columns) + 1));
    cell.setAttribute("aria-colindex", String((index % LEVEL_SCHEMA.columns) + 1));
    applyBrickStyle(cell, valueAt(index));
    fragment.append(cell);
  }
  elements.grid.append(fragment);
}

function renderPalette() {
  const fragment = document.createDocumentFragment();
  for (const code of ["cycle", ...LEVEL_SCHEMA.codes]) {
    const label =
      code === "cycle"
        ? "CYCLE"
        : code === LEVEL_SCHEMA.empty
          ? "ERASE"
          : BRICKS[code].name;
    const item = document.createElement("button");
    item.type = "button";
    item.className = "palette-chip";
    item.dataset.tool = code;
    item.setAttribute("aria-pressed", String(code === selectedTool));
    item.setAttribute("aria-label", `${label} paint tool`);
    if (code === "cycle") {
      item.textContent = label;
      fragment.append(item);
      continue;
    }
    const brick = BRICKS[code];
    const swatch = document.createElement("span");
    swatch.className = "palette-swatch";
    swatch.style.setProperty("--brick-color", brick.color);
    swatch.setAttribute("aria-hidden", "true");
    item.append(swatch, label);
    fragment.append(item);
  }
  elements.palette.replaceChildren(fragment);
}

function currentInput() {
  return {
    schema_version: LEVEL_SCHEMA.schemaVersion,
    level_name: elements.levelName.value,
    creator_display_name: elements.creatorName.value,
    layout,
  };
}

function updateValidation(showErrors = false) {
  const result = validateLevel(currentInput());
  elements.levelNameError.textContent = showErrors ? result.errors.level_name : "";
  elements.creatorNameError.textContent = showErrors
    ? result.errors.creator_display_name
    : "";
  elements.levelName.setAttribute(
    "aria-invalid",
    String(showErrors && Boolean(result.errors.level_name)),
  );
  elements.creatorName.setAttribute(
    "aria-invalid",
    String(showErrors && Boolean(result.errors.creator_display_name)),
  );
  elements.blockCount.textContent = `${result.counts.populated} BRICKS`;
  elements.filledReadout.textContent =
    `${result.counts.populated} / ${LEVEL_SCHEMA.maxPopulated}`;
  elements.validityReadout.textContent = result.valid
    ? "READY"
    : result.errors.layout || "NEEDS LABELS";
  elements.submitButton.disabled = submitting || !result.valid;
  elements.clearButton.disabled = submitting || result.counts.populated === 0;
  return result;
}

function focusCell(cell) {
  for (const candidate of elements.grid.querySelectorAll(".grid-cell[tabindex='0']")) {
    candidate.tabIndex = -1;
  }
  cell.tabIndex = 0;
}

function paintCell(cell, code) {
  if (submitting) return;
  const index = Number(cell.dataset.index);
  if (valueAt(index) === code) return;
  setValueAt(index, code);
  applyBrickStyle(cell, code);
  updateValidation();
}

function selectTool(tool) {
  if (tool !== "cycle" && !LEVEL_SCHEMA.codes.includes(tool)) return;
  selectedTool = tool;
  for (const button of elements.palette.querySelectorAll(".palette-chip")) {
    button.setAttribute("aria-pressed", String(button.dataset.tool === tool));
  }
  for (const cell of elements.grid.querySelectorAll(".grid-cell")) {
    applyBrickStyle(cell, valueAt(Number(cell.dataset.index)));
  }
}

function cellAtPointer(event) {
  const hit = document.elementFromPoint(event.clientX, event.clientY);
  const cell = hit?.closest?.(".grid-cell");
  return cell && elements.grid.contains(cell) ? cell : null;
}

function beginPaint(event) {
  if (submitting || event.button !== 0) return;
  const cell = event.target.closest(".grid-cell");
  if (!cell) return;
  event.preventDefault();
  focusCell(cell);
  cell.focus({ preventScroll: true });
  painting = true;
  paintedIndexes = new Set();
  strokeCode = resolvePaintCode(
    selectedTool,
    valueAt(Number(cell.dataset.index)),
    event.shiftKey,
  );
  continuePaint(event, cell);
}

function continuePaint(event, knownCell = null) {
  if (!painting) return;
  event.preventDefault();
  const cell = knownCell || cellAtPointer(event);
  if (!cell) return;
  const index = Number(cell.dataset.index);
  if (paintedIndexes.has(index)) return;
  paintedIndexes.add(index);
  paintCell(cell, strokeCode);
}

function endPaint() {
  painting = false;
  paintedIndexes.clear();
}

function handleGridKeydown(event) {
  const cell = event.target.closest(".grid-cell");
  if (!cell) return;
  const index = Number(cell.dataset.index);
  let targetIndex = index;
  if (event.key === "ArrowLeft") targetIndex = Math.max(0, index - 1);
  if (event.key === "ArrowRight") {
    targetIndex = Math.min(LEVEL_SCHEMA.rows * LEVEL_SCHEMA.columns - 1, index + 1);
  }
  if (event.key === "ArrowUp") {
    targetIndex = Math.max(0, index - LEVEL_SCHEMA.columns);
  }
  if (event.key === "ArrowDown") {
    targetIndex = Math.min(
      LEVEL_SCHEMA.rows * LEVEL_SCHEMA.columns - 1,
      index + LEVEL_SCHEMA.columns,
    );
  }
  if (event.key === " " || event.key === "Enter") {
    event.preventDefault();
    focusCell(cell);
    paintCell(
      cell,
      resolvePaintCode(selectedTool, valueAt(index), event.shiftKey),
    );
    return;
  }
  if (targetIndex !== index) {
    event.preventDefault();
    cell.tabIndex = -1;
    const target = elements.grid.querySelector(`[data-index="${targetIndex}"]`);
    if (target) {
      target.tabIndex = 0;
      target.focus();
    }
  }
}

function setStatus(state, code, message, link = null) {
  elements.status.dataset.state = state;
  elements.status.replaceChildren();
  const codeElement = document.createElement("span");
  codeElement.className = "status-code";
  codeElement.textContent = code;
  const messageElement = document.createElement("p");
  messageElement.textContent = message;
  if (link) {
    const anchor = document.createElement("a");
    anchor.href = `../?community=${encodeURIComponent(link.id)}`;
    anchor.textContent = `PLAY ${link.id}`;
    messageElement.append(document.createElement("br"), anchor);
  }
  elements.status.append(codeElement, messageElement);
}

function friendlyError(status, body) {
  if (status === 429) {
    const retry = Number(body?.retry_after_seconds);
    return retry > 0
      ? `Submission limit reached. Try again in ${Math.ceil(retry / 60)} minutes.`
      : "Submission limit reached. Try again later.";
  }
  if (status === 409) return "This level already exists in the Community Lab.";
  if (status === 413) return "The level payload is too large.";
  if (status === 422 || status === 400) {
    return body?.message || "The server rejected this level. Check the labels and grid.";
  }
  if (status >= 500) return "The Community Lab is unavailable. Your grid is still here.";
  return body?.message || "Submission failed. Check your connection and try again.";
}

async function submitLevel(event) {
  event.preventDefault();
  const result = updateValidation(true);
  if (!result.valid) {
    setStatus("error", "CHECK LEVEL", result.errors.layout || "Fix the labeled fields.");
    (result.errors.level_name
      ? elements.levelName
      : result.errors.creator_display_name
        ? elements.creatorName
        : elements.grid.querySelector(".grid-cell")
    )?.focus();
    return;
  }

  submitting = true;
  updateValidation(true);
  setStatus("loading", "TRANSMITTING", "Sending the immutable cartridge to the Lab.");

  try {
    const response = await fetch(`${API_BASE}/submit-level`, {
      method: "POST",
      headers: {
        apikey: PUBLISHABLE_KEY,
        "content-type": "application/json",
      },
      body: JSON.stringify(result.normalized),
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw Object.assign(new Error(friendlyError(response.status, body)), {
        status: response.status,
      });
    }
    if (!isCommunityLevelId(body.id)) {
      throw new Error("The Lab returned an invalid level identifier.");
    }
    setStatus(
      "success",
      body.created ? "CARTRIDGE ACCEPTED" : "ALREADY IN LAB",
      body.status === "listed"
        ? `${result.normalized.level_name} is playable now as a listed, unranked level.`
        : `${result.normalized.level_name} is playable now as UNREVIEWED, unranked content.`,
      { id: body.id },
    );
    elements.status.focus();
  } catch (error) {
    setStatus("error", "SUBMISSION FAILED", error.message);
    elements.status.focus();
  } finally {
    submitting = false;
    updateValidation(true);
  }
}

function armOrClearGrid() {
  if (!clearArmed) {
    clearArmed = true;
    elements.clearButton.textContent = "PRESS AGAIN TO CLEAR";
    clearTimeout(clearTimer);
    clearTimer = window.setTimeout(() => {
      clearArmed = false;
      elements.clearButton.textContent = "CLEAR GRID";
    }, 3000);
    return;
  }
  clearTimeout(clearTimer);
  clearArmed = false;
  layout = emptyLayout();
  elements.clearButton.textContent = "CLEAR GRID";
  renderGrid();
  updateValidation();
  setStatus("ready", "GRID CLEARED", "The cartridge is blank and ready for a new layout.");
}

elements.palette.addEventListener("click", (event) => {
  const tool = event.target.closest(".palette-chip")?.dataset.tool;
  if (tool) selectTool(tool);
});
elements.grid.addEventListener("pointerdown", beginPaint);
window.addEventListener("pointermove", (event) => continuePaint(event));
window.addEventListener("pointerup", endPaint);
window.addEventListener("pointercancel", endPaint);
window.addEventListener("blur", endPaint);
elements.grid.addEventListener("keydown", handleGridKeydown);
elements.form.addEventListener("submit", submitLevel);
elements.clearButton.addEventListener("click", armOrClearGrid);
elements.levelName.addEventListener("input", () => updateValidation());
elements.creatorName.addEventListener("input", () => updateValidation());

renderGrid();
renderPalette();
updateValidation();
