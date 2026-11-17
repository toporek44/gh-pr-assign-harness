#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${HOME}/.config/gh/pr-default-assignees.json"
ROSTER_BIN="${HOME}/.local/bin/gh-pr-roster-json"
[[ -x "$ROOT/bin/gh-pr-roster-json" ]] && ROSTER_BIN="$ROOT/bin/gh-pr-roster-json"
if [[ ! -f "$CONFIG" ]] || ! command -v jq >/dev/null 2>&1; then echo '{}'; exit 0; fi
if [[ "$(jq -r '.agent_ask_before_pr_create // true' "$CONFIG")" != "true" ]]; then echo '{}'; exit 0; fi
roster='{}'
[[ -x "$ROSTER_BIN" ]] && roster=$("$ROSTER_BIN")
jq -n --argjson roster "$roster" \
  --arg hint "PR create workflow: Before gh pr create, AskQuestion allow_multiple with roster.options. First option __use_defaults__ = one-tap defaults. Or pick teammate ids (defaults listed first). Chat \"defaults\"/\"yes\" = roster.defaults. Map logins to --assignee; never shell UI. shell_ask off." \
  '{ "additional_context": ($hint + " Roster JSON: " + ($roster | tostring)) }'