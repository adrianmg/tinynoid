#!/usr/bin/env bash
set -euo pipefail

readonly SHORT_SHA="${GITHUB_SHA:0:7}"
readonly TITLE="Release failed for ${SHORT_SHA}"
readonly RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

existing_issue="$(
  gh issue list \
    --repo "$GITHUB_REPOSITORY" \
    --state open \
    --search "\"${TITLE}\" in:title" \
    --json number \
    --jq '.[0].number // empty'
)"

if [[ -n "$existing_issue" ]]; then
  gh issue comment "$existing_issue" \
    --repo "$GITHUB_REPOSITORY" \
    --body "Release rerun failed again: ${RUN_URL}"
else
  gh issue create \
    --repo "$GITHUB_REPOSITORY" \
    --title "$TITLE" \
    --body "The automated Pikonoid release failed for commit \`${GITHUB_SHA}\`.\n\nWorkflow: ${RUN_URL}\n\nRerun the failed workflow after correcting the reported job."
fi

