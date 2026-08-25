#!/usr/bin/env bash
set -euo pipefail

readonly SERVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT="$(cd "${SERVICE_DIR}/.." && pwd)"
readonly OUTPUT_DIR="${SERVICE_DIR}/public"

if [[ "$(uname -s)" == "Darwin" ]]; then
  GODOT_BIN="${GODOT_BIN:-$(command -v godot)}"
else
  export GITHUB_WORKSPACE="$ROOT"
  "${ROOT}/.github/scripts/setup-godot.sh"
  GODOT_BIN="${ROOT}/.ci/godot/Godot_v4.7.2-stable_linux.x86_64"
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

"$GODOT_BIN" --headless --editor --path "${ROOT}/godot" --quit
"$GODOT_BIN" --headless --quiet --path "${ROOT}/godot" \
  --export-release "Web" "${OUTPUT_DIR}/index.html"

cp -R "${ROOT}/web/editor" "${OUTPUT_DIR}/editor"
cp -R "${ROOT}/schema" "${OUTPUT_DIR}/schema"
cp "${ROOT}/web/og-image.png" "${OUTPUT_DIR}/og-image.png"

test -s "${OUTPUT_DIR}/index.html"
test -s "${OUTPUT_DIR}/index.wasm"
test -s "${OUTPUT_DIR}/index.pck"
test -s "${OUTPUT_DIR}/editor/index.html"
test -s "${OUTPUT_DIR}/editor/og-image.png"
test -s "${OUTPUT_DIR}/schema/community-level-v1.schema.json"
