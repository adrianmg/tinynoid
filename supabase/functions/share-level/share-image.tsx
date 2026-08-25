import React from "https://esm.sh/react@18.2.0?deno-std=0.177.0";
import { ImageResponse } from "https://deno.land/x/og_edge@0.0.4/mod.ts";
import type { SharedCommunityLevel } from "../_shared/community-share.ts";

const COLORS: Record<string, string> = {
  ".": "#050611",
  W: "#f7f4ff",
  O: "#ff8a3d",
  C: "#74ddff",
  G: "#56d46f",
  R: "#f15b68",
  B: "#6d83f2",
  P: "#c967e8",
  Y: "#ffd84a",
  S: "#aab3c8",
  X: "#d7a72e",
};

const GLYPHS: Record<string, string[]> = {
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
  "@": ["01110", "10001", "10111", "10101", "01111"],
  "_": ["0", "0", "0", "0", "111"],
  ".": ["0", "0", "0", "0", "1"],
  "/": ["001", "001", "010", "100", "100"],
  "-": ["0", "0", "1", "0", "0"],
  "?": ["110", "001", "010", "000", "010"],
};

function glyphAdvance(character: string): number {
  return character === "@" ? 6 : 4;
}

function textWidth(text: string, scale: number): number {
  if (text.length === 0) return 0;
  let width = 0;
  for (const character of text) {
    width += (character === " " ? 4 : glyphAdvance(character)) * scale;
  }
  return width - scale;
}

function wrapLevelName(text: string): string[] {
  const words = text.split(" ");
  const lines: string[] = [];
  let line = "";
  for (const word of words) {
    const candidate = line.length === 0 ? word : `${line} ${word}`;
    if (candidate.length <= 16) {
      line = candidate;
      continue;
    }
    if (line.length > 0) lines.push(line);
    if (word.length <= 16) {
      line = word;
    } else {
      lines.push(word.slice(0, 16));
      line = word.slice(16, 32);
    }
  }
  if (line.length > 0) lines.push(line);
  return lines.slice(0, 2);
}

function formatCreatorName(value: string): string {
  const normalized = value.trim().toUpperCase();
  if (normalized.length === 0) return "UNKNOWN";
  return normalized.startsWith("@") ? normalized : `@${normalized}`;
}

function PixelText(
  props: {
    text: string;
    scale: number;
    color: string;
    lineGap?: number;
  },
): React.ReactElement {
  const lines = props.text.toUpperCase().split("\n");
  const lineGap = props.lineGap ?? props.scale * 2;
  const width = Math.max(...lines.map((line) => textWidth(line, props.scale)));
  const height = lines.length * 5 * props.scale +
    (lines.length - 1) * lineGap;
  const pixels: React.ReactElement[] = [];
  lines.forEach((line, lineIndex) => {
    let cursorX = 0;
    for (const character of line) {
      if (character === " ") {
        cursorX += 4 * props.scale;
        continue;
      }
      const rows = GLYPHS[character] ?? GLYPHS["?"];
      rows.forEach((row, rowIndex) => {
        [...row].forEach((pixel, columnIndex) => {
          if (pixel !== "1") return;
          pixels.push(
            <rect
              key={`${lineIndex}-${cursorX}-${rowIndex}-${columnIndex}`}
              x={cursorX + columnIndex * props.scale}
              y={lineIndex * (5 * props.scale + lineGap) +
                rowIndex * props.scale}
              width={props.scale}
              height={props.scale}
              fill={props.color}
            />,
          );
        });
      });
      cursorX += glyphAdvance(character) * props.scale;
    }
  });
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
      {pixels}
    </svg>
  );
}

function BrickCell({ code }: { code: string }): React.ReactElement {
  const filled = code !== ".";
  return (
    <div
      style={{
        display: "flex",
        position: "relative",
        width: 36,
        height: 26,
        border: "2px solid #12345b",
        background: COLORS[code] ?? COLORS["."],
      }}
    >
      {filled
        ? (
          <div
            style={{
              display: "flex",
              position: "absolute",
              left: 2,
              right: 2,
              top: 2,
              height: 3,
              background: "#f7f4ff",
            }}
          />
        )
        : null}
    </div>
  );
}

export function renderCommunityLevelImage(
  level: SharedCommunityLevel,
): Response {
  const titleLines = wrapLevelName(level.level_name);
  const titleScale = titleLines.some((line) => line.length > 13) ? 6 : 8;
  const status = level.status === "listed" ? "LISTED" : "UNREVIEWED";
  return new ImageResponse(
    <div
      style={{
        display: "flex",
        position: "relative",
        width: "100%",
        height: "100%",
        color: "#f7f4ff",
        background: "#050611",
      }}
    >
      <div
        style={{
          display: "flex",
          position: "absolute",
          left: 28,
          top: 28,
          width: 1144,
          height: 574,
          border: "4px solid #287fc4",
          borderTop: "10px solid #74ddff",
          boxShadow: "10px 10px 0 #12345b",
        }}
      />
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          position: "absolute",
          left: 68,
          top: 66,
          width: 420,
        }}
      >
        <PixelText text="TINYNOID" scale={8} color="#74ddff" />
        <div style={{ display: "flex", height: 28 }} />
        <PixelText
          text="SHARED COMMUNITY LEVEL"
          scale={3}
          color="#ffd84a"
        />
        <div
          style={{
            display: "flex",
            width: 370,
            height: 8,
            marginTop: 30,
            marginBottom: 30,
            borderTop: "3px solid #74ddff",
            borderBottom: "3px solid #287fc4",
          }}
        />
        <PixelText
          text={titleLines.join("\n")}
          scale={titleScale}
          lineGap={titleScale * 2}
          color="#f7f4ff"
        />
        <div style={{ display: "flex", height: 28 }} />
        <PixelText
          text={`BY ${formatCreatorName(level.creator_display_name)}`}
          scale={4}
          color="#c967e8"
        />
        <div
          style={{
            display: "flex",
            alignSelf: "flex-start",
            marginTop: 30,
            padding: "12px 16px",
            border: `3px solid ${
              level.status === "listed" ? "#74ddff" : "#56d46f"
            }`,
          }}
        >
          <PixelText
            text={`${status} / UNRANKED`}
            scale={3}
            color={level.status === "listed" ? "#74ddff" : "#56d46f"}
          />
        </div>
      </div>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          position: "absolute",
          top: 52,
          right: 58,
          width: 624,
          height: 520,
          padding: 22,
          border: "6px solid #287fc4",
          borderTopColor: "#74ddff",
          background: "#111329",
          boxShadow: "10px 10px 0 #12345b",
        }}
      >
        <div
          style={{
            display: "flex",
            paddingBottom: 16,
            borderBottom: "3px solid #287fc4",
          }}
        >
          <PixelText text="COMMUNITY LAB" scale={3} color="#74ddff" />
        </div>
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignSelf: "center",
            marginTop: 22,
            padding: 12,
            border: "4px solid #287fc4",
            borderTopColor: "#74ddff",
            background: "#050611",
          }}
        >
          {level.layout.map((row, rowIndex) => (
            <div
              key={rowIndex}
              style={{
                display: "flex",
                gap: 5,
                marginBottom: rowIndex < 9 ? 5 : 0,
              }}
            >
              {[...row].map((code, columnIndex) => (
                <BrickCell key={`${rowIndex}-${columnIndex}`} code={code} />
              ))}
            </div>
          ))}
        </div>
        <div
          style={{
            display: "flex",
            justifyContent: "flex-end",
            marginTop: 20,
          }}
        >
          <div
            style={{
              display: "flex",
              padding: "12px 16px",
              border: "3px solid #74ddff",
              color: "#050611",
              background: "#74ddff",
              boxShadow: "5px 5px 0 #287fc4",
            }}
          >
            <PixelText text="PLAY THIS LEVEL" scale={3} color="#050611" />
          </div>
        </div>
      </div>
    </div>,
    {
      width: 1200,
      height: 630,
    },
  );
}
