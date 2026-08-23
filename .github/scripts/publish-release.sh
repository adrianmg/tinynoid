#!/usr/bin/env bash
set -euo pipefail

readonly DIST_DIR="${1:-dist}"
readonly SHORT_SHA="${GITHUB_SHA:0:7}"
readonly TAG="main-build-${GITHUB_RUN_NUMBER}-${SHORT_SHA}"
readonly TITLE="TINYNOID main build #${GITHUB_RUN_NUMBER} (${SHORT_SHA})"
readonly EXPECTED_ASSETS=(
  "SHA256SUMS"
  "tinynoid-linux-x86_64.tar.gz"
  "tinynoid-macos-universal.zip"
  "tinynoid-web.zip"
  "tinynoid-windows-x86_64.zip"
)

body_file="$(mktemp)"
cat > "$body_file" <<BODY
Automated TINYNOID build from \`${GITHUB_SHA}\`.

- Godot: 4.7.2 stable
- Workflow: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
- Verify downloads with \`sha256sum --check SHA256SUMS\`.
- Windows and macOS builds are currently unsigned.
BODY

if gh release view "$TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$TAG" "${DIST_DIR}"/* \
    --repo "$GITHUB_REPOSITORY" \
    --clobber
else
  gh release create "$TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --target "$GITHUB_SHA" \
    --title "$TITLE" \
    --notes-file "$body_file" \
    --generate-notes \
    --prerelease \
    --draft
  gh release upload "$TAG" "${DIST_DIR}"/* \
    --repo "$GITHUB_REPOSITORY"
fi

mapfile -t actual_assets < <(
  gh release view "$TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --json assets \
    --jq '.assets[].name' \
    | sort
)

if [[ "${actual_assets[*]}" != "${EXPECTED_ASSETS[*]}" ]]; then
  printf 'Expected assets:\n%s\n' "${EXPECTED_ASSETS[*]}" >&2
  printf 'Actual assets:\n%s\n' "${actual_assets[*]}" >&2
  exit 1
fi

gh release edit "$TAG" \
  --repo "$GITHUB_REPOSITORY" \
  --draft=false \
  --prerelease

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'tag=%s\n' "$TAG" >> "$GITHUB_OUTPUT"
  printf 'url=%s\n' "$(
    gh release view "$TAG" \
      --repo "$GITHUB_REPOSITORY" \
      --json url \
      --jq '.url'
  )" >> "$GITHUB_OUTPUT"
fi

rm -f "$body_file"
