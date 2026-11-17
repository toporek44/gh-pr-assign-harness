#!/usr/bin/env bash
# Claude Code PostToolUse (Bash): backfill assignees after gh pr create.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/gh-pr-assign-common.sh
source "$ROOT/lib/gh-pr-assign-common.sh"
INPUT=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

COMMAND=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
OUTPUT=$(jq -r '.tool_response.stdout // .tool_response.content // empty' <<<"$INPUT")

if [[ ! "$COMMAND" =~ gh[[:space:]].*pr[[:space:]]+create ]]; then
  exit 0
fi
if [[ "$COMMAND" =~ --dry-run || "$COMMAND" =~ --assignee ]]; then
  exit 0
fi

PR_URL=$(grep -oE 'https?://[^[:space:]]+/pull/[0-9]+' <<<"$OUTPUT" | head -1 || true)
[[ -n "$PR_URL" ]] || exit 0

{
  read -r host
  read -r repo
  read -r number
} < <(gh_pr_parse_pull_url "$PR_URL" || true)

gh_pr_add_default_assignees "$host" "$repo" "$number"
exit 0