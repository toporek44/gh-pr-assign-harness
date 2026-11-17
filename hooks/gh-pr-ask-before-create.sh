#!/usr/bin/env bash
# Cursor beforeShellExecution
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/gh-pr-ask-message.sh
source "$ROOT/lib/gh-pr-ask-message.sh"
CONFIG="${HOME}/.config/gh/pr-default-assignees.json"
ROSTER_BIN="${HOME}/.local/bin/gh-pr-roster-json"
INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo '{ "permission": "allow" }'
  exit 0
fi

COMMAND=$(jq -r '.command // empty' <<<"$INPUT")
if [[ ! "$COMMAND" =~ gh[[:space:]].*pr[[:space:]]+create ]]; then
  echo '{ "permission": "allow" }'
  exit 0
fi
if [[ "$COMMAND" =~ --dry-run ]]; then
  echo '{ "permission": "allow" }'
  exit 0
fi
if ! gh_pr_should_ask_before_create "$CONFIG"; then
  echo '{ "permission": "allow" }'
  exit 0
fi

msg=$(gh_pr_build_ask_message "$CONFIG" "$ROSTER_BIN")
jq -n --arg um "$msg" \
  '{
    "permission": "ask",
    "user_message": $um,
    "agent_message": "If rejected, use AskQuestion with gh-pr-roster-json before gh pr create."
  }'