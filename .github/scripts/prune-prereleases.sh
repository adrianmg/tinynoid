#!/usr/bin/env bash
set -euo pipefail

readonly KEEP_COUNT="${KEEP_COUNT:-30}"

mapfile -t stale_tags < <(
  gh release list \
    --repo "$GITHUB_REPOSITORY" \
    --limit 200 \
    --json tagName,isPrerelease,publishedAt \
    --jq '
      [
        .[]
        | select(.isPrerelease)
        | select(.tagName | startswith("main-build-"))
      ]
      | sort_by(.publishedAt)
      | reverse
      | .['"${KEEP_COUNT}"':]
      | .[].tagName
    '
)

for tag in "${stale_tags[@]}"; do
  gh release delete "$tag" \
    --repo "$GITHUB_REPOSITORY" \
    --cleanup-tag \
    --yes
done

