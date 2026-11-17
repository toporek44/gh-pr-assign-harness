#!/usr/bin/env bash
# Claude Code PreToolUse (Bash): confirm assignees before gh pr create.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/gh-pr-ask-message.sh
source "$ROOT/lib/gh-pr-ask-message.sh"
CONFIG="${HOME}/.config/gh/pr-default-assignees.json"
ROSTER_BIN="${HOME}/.local/bin/gh-pr-roster-json"
INPUT=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

COMMAND=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
if [[ ! "$COMMAND" =~ gh[[:space:]].*pr[[:space:]]+create ]]; then
  exit 0
fi
if [[ "$COMMAND" =~ --dry-run ]]; then
  exit 0
fi
if ! gh_pr_should_ask_before_create "$CONFIG"; then
  exit 0
fi

msg=$(gh_pr_build_ask_message "$CONFIG" "$ROSTER_BIN")
jq -n \
  --arg reason "$msg" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "ask",
      "permissionDecisionReason": $reason
    }
  }'