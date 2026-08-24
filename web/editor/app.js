import {
  LEVEL_SCHEMA,
  emptyLayout,
  isCommunityLevelId,
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
  gridSize: document.querySelector("#grid-size"),
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

function nextCode(code) {
  const index = LEVEL_SCHEMA.codes.indexOf(code);
  return LEVEL_SCHEMA.codes[(index + 1) % LEVEL_SCHEMA.codes.length];
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
  const next = BRICKS[nextCode(code)].name;
  cell.setAttribute(
    "aria-label",
    `Row ${row}, column ${column}: ${brick.name}. Activate for ${next}.`,
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
  for (const code of LEVEL_SCHEMA.codes) {
    const brick = BRICKS[code];
    const item = document.createElement("span");
    item.className = "palette-chip";
    const swatch = document.createElement("span");
    swatch.className = "palette-swatch";
    swatch.style.setProperty("--brick-color", brick.color);
    swatch.setAttribute("aria-hidden", "true");
    item.append(swatch, brick.name);
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
  elements.gridSize.textContent = `${LEVEL_SCHEMA.columns} × ${LEVEL_SCHEMA.rows}`;
  elements.filledReadout.textContent =
    `${result.counts.populated} / ${LEVEL_SCHEMA.maxPopulated}`;
  elements.validityReadout.textContent = result.valid
    ? "READY"
    : result.errors.layout || "NEEDS LABELS";
  elements.submitButton.disabled = submitting || !result.valid;
  elements.clearButton.disabled = submitting || result.counts.populated === 0;
  return result;
}

function cycleCell(cell) {
  if (submitting) return;
  for (const candidate of elements.grid.querySelectorAll(".grid-cell[tabindex='0']")) {
    candidate.tabIndex = -1;
  }
  cell.tabIndex = 0;
  const index = Number(cell.dataset.index);
  const value = nextCode(valueAt(index));
  setValueAt(index, value);
  applyBrickStyle(cell, value);
  updateValidation();
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
    cycleCell(cell);
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

elements.grid.addEventListener("click", (event) => {
  const cell = event.target.closest(".grid-cell");
  if (cell) cycleCell(cell);
});
elements.grid.addEventListener("keydown", handleGridKeydown);
elements.form.addEventListener("submit", submitLevel);
elements.clearButton.addEventListener("click", armOrClearGrid);
elements.levelName.addEventListener("input", () => updateValidation());
elements.creatorName.addEventListener("input", () => updateValidation());

renderGrid();
renderPalette();
updateValidation();
