#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
readonly PROJECT_DIR="${ROOT}/godot"
readonly BUILD_DIR="${PROJECT_DIR}/build"
readonly DIST_DIR="${ROOT}/dist"
readonly GODOT_BIN="${GODOT_BIN:?GODOT_BIN must point to Godot 4.7.2}"

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p \
  "$DIST_DIR" \
  "${BUILD_DIR}/web" \
  "${BUILD_DIR}/windows" \
  "${BUILD_DIR}/linux" \
  "${BUILD_DIR}/macos"

"$GODOT_BIN" --headless --editor --path "$PROJECT_DIR" --quit
"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
  res://tests/test_runner.tscn
node --test "${ROOT}/web/tests/"*.test.mjs

"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
  --export-release "Web"
test -s "${BUILD_DIR}/web/index.html"
test -s "${BUILD_DIR}/web/index.wasm"
test -s "${BUILD_DIR}/web/index.pck"
cp -R "${ROOT}/web/editor" "${BUILD_DIR}/web/editor"
cp -R "${ROOT}/schema" "${BUILD_DIR}/web/schema"
test -s "${BUILD_DIR}/web/editor/index.html"
test -s "${BUILD_DIR}/web/editor/app.js"
test -s "${BUILD_DIR}/web/schema/community-level-v1.schema.json"

"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
  --export-release "Windows Desktop"
test -s "${BUILD_DIR}/windows/TINYNOID.exe"

"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
  --export-release "Linux/X11"
test -s "${BUILD_DIR}/linux/TINYNOID.x86_64"
chmod +x "${BUILD_DIR}/linux/TINYNOID.x86_64"
"${BUILD_DIR}/linux/TINYNOID.x86_64" --headless --quit-after 2

"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
  --export-release "macOS"
test -s "${BUILD_DIR}/macos/TINYNOID.zip"
unzip -tq "${BUILD_DIR}/macos/TINYNOID.zip"
unzip -l "${BUILD_DIR}/macos/TINYNOID.zip" \
  | grep -q 'TINYNOID.app/Contents/Info.plist'
unzip -l "${BUILD_DIR}/macos/TINYNOID.zip" \
  | grep -q 'TINYNOID.app/Contents/MacOS/TINYNOID'

(
  cd "${BUILD_DIR}/web"
  zip -X -q -r "${DIST_DIR}/tinynoid-web.zip" .
)

(
  cd "${BUILD_DIR}/windows"
  zip -X -q "${DIST_DIR}/tinynoid-windows-x86_64.zip" \
    TINYNOID.exe
)

source_date_epoch="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT" log -1 --format=%ct)}"
tar \
  --sort=name \
  --mtime="@${source_date_epoch}" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -C "${BUILD_DIR}/linux" \
  -czf "${DIST_DIR}/tinynoid-linux-x86_64.tar.gz" \
  TINYNOID.x86_64

cp "${BUILD_DIR}/macos/TINYNOID.zip" \
  "${DIST_DIR}/tinynoid-macos-universal.zip"

(
  cd "$DIST_DIR"
  sha256sum \
    tinynoid-web.zip \
    tinynoid-windows-x86_64.zip \
    tinynoid-linux-x86_64.tar.gz \
    tinynoid-macos-universal.zip \
    > SHA256SUMS
  sha256sum --check SHA256SUMS
)

find "$DIST_DIR" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
