#!/usr/bin/env bash
# Claude Code SessionStart: PR assignee picker instructions + roster.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${HOME}/.config/gh/pr-default-assignees.json"
ROSTER_BIN="${HOME}/.local/bin/gh-pr-roster-json"
[[ -x "$ROOT/bin/gh-pr-roster-json" ]] && ROSTER_BIN="$ROOT/bin/gh-pr-roster-json"

command -v jq >/dev/null 2>&1 || exit 0
[[ -f "$CONFIG" ]] || exit 0
[[ "$(jq -r '.agent_ask_before_pr_create // true' "$CONFIG")" == "true" ]] || exit 0

roster=$("$ROSTER_BIN" 2>/dev/null || echo '{}')
hint="PR workflow: before gh pr create, use AskUserQuestion (multi) with gh-pr-roster-json options. First id __use_defaults__ is one-tap defaults. Chat \"defaults\"/\"yes\" = defaults array. Map ids to --assignee."

jq -n \
  --arg ctx "$hint Roster: $(echo "$roster" | jq -c .)" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "SessionStart",
      "additionalContext": $ctx
    }
  }'