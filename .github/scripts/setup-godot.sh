#!/usr/bin/env bash
set -euo pipefail

readonly GODOT_VERSION="4.7.2"
readonly GODOT_CHANNEL="stable"
readonly GODOT_RELEASE="${GODOT_VERSION}-${GODOT_CHANNEL}"
readonly GODOT_TEMPLATE_VERSION="${GODOT_VERSION}.${GODOT_CHANNEL}"
readonly EDITOR_ARCHIVE="Godot_v${GODOT_RELEASE}_linux.x86_64.zip"
readonly TEMPLATE_ARCHIVE="Godot_v${GODOT_RELEASE}_export_templates.tpz"
readonly EDITOR_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
readonly TEMPLATE_SHA512="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
readonly RELEASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}"
readonly TOOL_DIR="${GITHUB_WORKSPACE:-$(pwd)}/.ci/godot"
readonly GODOT_BIN="${TOOL_DIR}/Godot_v${GODOT_RELEASE}_linux.x86_64"
readonly TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_TEMPLATE_VERSION}"

download_and_verify() {
  local url="$1"
  local destination="$2"
  local sha512="$3"

  curl --fail --location --retry 3 --silent --show-error \
    "$url" --output "$destination"
  printf '%s  %s\n' "$sha512" "$destination" | sha512sum --check -
}

if [[ ! -x "$GODOT_BIN" ]]; then
  mkdir -p "$TOOL_DIR"
  archive="$(mktemp)"
  download_and_verify \
    "${RELEASE_URL}/${EDITOR_ARCHIVE}" \
    "$archive" \
    "$EDITOR_SHA512"
  unzip -q -o "$archive" -d "$TOOL_DIR"
  chmod +x "$GODOT_BIN"
  rm -f "$archive"
fi

if [[ "${GODOT_INSTALL_TEMPLATES:-1}" == "1" && ! -f "${TEMPLATE_DIR}/version.txt" ]]; then
  archive="$(mktemp)"
  extract_dir="$(mktemp -d)"
  download_and_verify \
    "${RELEASE_URL}/${TEMPLATE_ARCHIVE}" \
    "$archive" \
    "$TEMPLATE_SHA512"
  unzip -q "$archive" -d "$extract_dir"
  rm -rf "$TEMPLATE_DIR"
  mkdir -p "$(dirname "$TEMPLATE_DIR")"
  mv "${extract_dir}/templates" "$TEMPLATE_DIR"
  rm -rf "$archive" "$extract_dir"
fi

"$GODOT_BIN" --version

if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'GODOT_BIN=%s\n' "$GODOT_BIN" >> "$GITHUB_ENV"
fi

if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "$TOOL_DIR" >> "$GITHUB_PATH"
fi
