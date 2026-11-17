#!/usr/bin/env bash
# beforeShellExecution: confirm assignees before gh pr create (chat ask + this gate).
set -euo pipefail
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

should_ask=false
if [[ -f "$CONFIG" ]]; then
  if [[ "$(jq -r '.agent_ask_before_pr_create // true' "$CONFIG")" == "true" ]]; then
    should_ask=true
  fi
  if [[ "$(jq -r '.shell_ask_before_pr_create // false' "$CONFIG")" == "true" ]]; then
    should_ask=true
  fi
else
  should_ask=true
fi

if [[ "$should_ask" != true ]]; then
  echo '{ "permission": "allow" }'
  exit 0
fi

msg=$(jq -r '.agent_ask_message // "Who should be assigned to this PR?"' "$CONFIG" 2>/dev/null || echo "Who should be assigned to this PR?")
defaults=$(jq -r '[.default_assignees[]?] | join(", ")' "$CONFIG" 2>/dev/null || true)
roster_line=""
if [[ -x "$ROSTER_BIN" ]]; then
  roster_line=$("$ROSTER_BIN" 2>/dev/null | jq -r '[.options[].label] | join(" | ")' 2>/dev/null || true)
fi

user_msg="$msg"
if [[ -n "$defaults" ]]; then
  user_msg="$msg Default assignees on command: $defaults."
fi
user_msg="$user_msg Approve to run gh pr create, or reject and pick assignees in chat first (gh-pr-roster-json / AskQuestion)."
if [[ -n "$roster_line" ]]; then
  user_msg="$user_msg Options: $roster_line"
fi

jq -n \
  --arg um "$user_msg" \
  '{
    "permission": "ask",
    "user_message": $um,
    "agent_message": "User must confirm assignees. If rejected, use AskQuestion with gh-pr-roster-json before retrying gh pr create."
  }'