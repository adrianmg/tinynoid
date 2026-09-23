#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly PROJECT_DIR="${ROOT}/godot"
readonly OUTPUT_DIR="${PROJECT_DIR}/build/wavedash"
readonly GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"

if [[ -z "$GODOT_BIN" ]]; then
  echo "Set GODOT_BIN to Godot 4.7.2 or add godot to PATH." >&2
  exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

"$GODOT_BIN" --headless --editor --path "$PROJECT_DIR" --quit
"$GODOT_BIN" --headless --quiet --path "$PROJECT_DIR" \
  --export-release "Web" "${OUTPUT_DIR}/index.html"

test -s "${OUTPUT_DIR}/index.html"
test -s "${OUTPUT_DIR}/index.js"
test -s "${OUTPUT_DIR}/index.wasm"
test -s "${OUTPUT_DIR}/index.pck"
grep -q "wavedash?.init()" "${OUTPUT_DIR}/index.html"

du -sh "$OUTPUT_DIR"
