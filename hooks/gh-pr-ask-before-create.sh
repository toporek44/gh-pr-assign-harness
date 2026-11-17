#!/usr/bin/env bash
set -euo pipefail
CONFIG="${HOME}/.config/gh/pr-default-assignees.json"
INPUT=$(cat)
command -v jq >/dev/null 2>&1 || { echo '{ "permission": "allow" }'; exit 0; }
COMMAND=$(jq -r '.command // empty' <<<"$INPUT")
if [[ ! "$COMMAND" =~ gh[[:space:]].*pr[[:space:]]+create ]]; then
  echo '{ "permission": "allow" }'; exit 0
fi
if [[ "$COMMAND" =~ gh-pr-create ]]; then echo '{ "permission": "allow" }'; exit 0; fi
if [[ -f "$CONFIG" ]] && [[ "$(jq -r '.shell_ask_before_pr_create // false' "$CONFIG")" != "true" ]]; then
  echo '{ "permission": "allow" }'; exit 0
fi
msg=$(jq -r '.agent_ask_message // "Have you assigned people to this PR?"' "$CONFIG" 2>/dev/null || echo "Have you assigned people to this PR?")
defaults=$(jq -r '[.default_assignees[]?] | join(", ")' "$CONFIG" 2>/dev/null || true)
user_msg="$msg"
[[ -n "$defaults" ]] && user_msg="$msg Defaults: $defaults."
jq -n --arg um "$user_msg" '{ "permission": "ask", "user_message": $um, "agent_message": "Confirm assignees before gh pr create." }'