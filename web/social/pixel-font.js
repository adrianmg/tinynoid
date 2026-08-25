// Mirrors godot/scripts/pixel_font.gd for consistent social-card typography.
const GLYPHS = {
  "0": ["111", "101", "101", "101", "111"],
  "1": ["010", "110", "010", "010", "111"],
  "2": ["110", "001", "010", "100", "111"],
  "3": ["110", "001", "010", "001", "110"],
  "4": ["101", "101", "111", "001", "001"],
  "5": ["111", "100", "110", "001", "110"],
  "6": ["011", "100", "110", "101", "010"],
  "7": ["111", "001", "010", "010", "010"],
  "8": ["010", "101", "010", "101", "010"],
  "9": ["010", "101", "011", "001", "110"],
  A: ["010", "101", "111", "101", "101"],
  B: ["110", "101", "110", "101", "110"],
  C: ["011", "100", "100", "100", "011"],
  D: ["110", "101", "101", "101", "110"],
  E: ["111", "100", "110", "100", "111"],
  F: ["111", "100", "110", "100", "100"],
  G: ["011", "100", "101", "101", "011"],
  H: ["101", "101", "111", "101", "101"],
  I: ["111", "010", "010", "010", "111"],
  J: ["001", "001", "001", "101", "010"],
  K: ["101", "101", "110", "101", "101"],
  L: ["100", "100", "100", "100", "111"],
  M: ["101", "111", "111", "101", "101"],
  N: ["101", "111", "111", "111", "101"],
  O: ["010", "101", "101", "101", "010"],
  P: ["110", "101", "110", "100", "100"],
  Q: ["010", "101", "101", "111", "011"],
  R: ["110", "101", "110", "101", "101"],
  S: ["011", "100", "010", "001", "110"],
  T: ["111", "010", "010", "010", "010"],
  U: ["101", "101", "101", "101", "111"],
  V: ["101", "101", "101", "101", "010"],
  W: ["101", "101", "111", "111", "101"],
  X: ["101", "101", "010", "101", "101"],
  Y: ["101", "101", "010", "010", "010"],
  Z: ["111", "001", "010", "100", "111"],
  ".": ["0", "0", "0", "0", "1"],
  "/": ["001", "001", "010", "100", "100"],
  "-": ["0", "0", "1", "0", "0"],
  "?": ["110", "001", "010", "000", "010"],
};

function measure(text, scale) {
  let width = 0;
  for (const character of text) {
    width += (character === " " ? 4 : 4) * scale;
  }
  return Math.max(0, width - scale);
}

function drawLine(context, text, y, scale, color, offsetX = 0, offsetY = 0) {
  let cursorX = 0;
  for (const character of text) {
    if (character === " ") {
      cursorX += 4 * scale;
      continue;
    }
    const rows = GLYPHS[character] ?? GLYPHS["?"];
    rows.forEach((row, rowIndex) => {
      [...row].forEach((pixel, columnIndex) => {
        if (pixel !== "1") return;
        context.fillRect(
          offsetX + cursorX + columnIndex * scale,
          offsetY + y + rowIndex * scale,
          scale,
          scale,
        );
      });
    });
    cursorX += 4 * scale;
  }
}

for (const element of document.querySelectorAll("[data-pixel]")) {
  const text = (element.dataset.text || element.textContent)
    .trim()
    .toUpperCase();
  const lines = text.split("|");
  const scale = Number(element.dataset.scale || 4);
  const lineGap = Number(element.dataset.lineGap || scale * 2);
  const shadow = element.dataset.shadow
    ? element.dataset.shadow.split(",")
    : null;
  const shadowX = shadow ? Number(shadow[0]) : 0;
  const shadowY = shadow ? Number(shadow[1]) : 0;
  const width = Math.max(...lines.map((line) => measure(line, scale)));
  const height = lines.length * 5 * scale + (lines.length - 1) * lineGap;
  const canvas = document.createElement("canvas");
  canvas.width = width + shadowX;
  canvas.height = height + shadowY;
  canvas.style.width = `${canvas.width}px`;
  canvas.style.height = `${canvas.height}px`;
  const context = canvas.getContext("2d");
  if (shadow) {
    context.fillStyle = shadow[2];
    lines.forEach((line, index) => {
      drawLine(
        context,
        line,
        index * (5 * scale + lineGap),
        scale,
        shadow[2],
        shadowX,
        shadowY,
      );
    });
  }
  context.fillStyle = element.dataset.color || "#f7f4ff";
  lines.forEach((line, index) => {
    drawLine(
      context,
      line,
      index * (5 * scale + lineGap),
      scale,
      element.dataset.color || "#f7f4ff",
    );
  });
  element.replaceChildren(canvas);
}
