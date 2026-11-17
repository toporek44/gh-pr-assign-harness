#!/usr/bin/env bash
# gh-pr-assign-harness — roster, gh-pr-create, Cursor/Claude hooks (HOOK_MODE=session|ask|after).
set -euo pipefail

CONFIG="${GH_PR_ASSIGNEES_CONFIG:-$HOME/.config/gh/pr-default-assignees.json}"

_should_ask() {
  [[ -f "$CONFIG" ]] || return 0
  [[ "$(jq -r '.agent_ask_before_pr_create // true' "$CONFIG")" == "true" ]] && return 0
  [[ "$(jq -r '.shell_ask_before_pr_create // false' "$CONFIG")" == "true" ]] && return 0
  return 1
}

_default_host() {
  if [[ -n "${GH_HOST:-}" ]]; then printf '%s\n' "$GH_HOST"; return; fi
  if [[ -f "$CONFIG" ]]; then
    local h
    h=$(jq -r '.default_gh_host // empty' "$CONFIG")
    [[ -n "$h" && "$h" != "null" ]] && { printf '%s\n' "$h"; return; }
  fi
  printf '%s\n' "github.com"
}

_assignees_for_host() {
  local host="${1:-github.com}"
  [[ -f "$CONFIG" ]] || return 0
  jq -r --arg h "$host" '
    if (.hosts[$h].assignees | length) > 0 then .hosts[$h].assignees[]
    else .default_assignees[]? // empty
    end
  ' "$CONFIG"
}

_cmd_roster() {
  command -v jq >/dev/null 2>&1 || { echo '{"defaults":[],"options":[]}'; return; }
  [[ -f "$CONFIG" ]] || { echo '{"defaults":[],"options":[]}'; return; }
  jq '
    .default_assignees as $def | (.teammates // []) as $team | .agent_ask_message as $msg |
    ([ $def[] as $login | ( $team[] | select(.login == $login) ) // {login: $login, name: $login} | . + {recommended: true} ] +
     ([ $team[] | select(.login as $l | ($def | index($l)) | not) ] | sort_by(.name))) as $ordered |
    ([ $def[] as $login | (($team[] | select(.login == $login) | .name) // $login) ] | join(", ")) as $dl |
    { ask_message: ($msg // "Who should be assigned to this PR?"), defaults: $def,
      options: [{ id: "__use_defaults__", label: ("Use defaults only: " + $dl + " (Recommended)") }] +
        [ $ordered[] | { id: .login, label: ((.name // .login) + " (" + .login + ")" + (if .recommended then " (default)" else "" end)) } ]
    }
  ' "$CONFIG"
}

_cmd_create() {
  if [[ " $* " == *" --assignee "* ]]; then exec gh pr create "$@"; fi
  local host args=() login
  host=$(_default_host)
  GH_HOST="$host"
  while IFS= read -r login; do
    [[ -n "$login" ]] && args+=(--assignee "$login")
  done < <(_assignees_for_host "$host")
  exec gh pr create "$@" "${args[@]}"
}

_ask_message() {
  local msg defaults dl
  msg=$(jq -r '.agent_ask_message // "Who should be assigned to this PR?"' "$CONFIG" 2>/dev/null)
  defaults=$(jq -r '[.default_assignees[]?] | join(", ")' "$CONFIG" 2>/dev/null)
  printf '%s' "$msg"
  [[ -n "$defaults" ]] && printf ' Defaults: %s.' "$defaults"
  printf ' Confirm assignees or reject and pick via gh-pr-roster-json first.'
}

_parse_cmd() {
  local input="$1"
  if echo "$input" | jq -e '.command' >/dev/null 2>&1; then
    jq -r '.command // empty' <<<"$input"
  else
    jq -r '.tool_input.command // empty' <<<"$input"
  fi
}

_is_pr_create() { [[ "$1" =~ gh[[:space:]].*pr[[:space:]]+create ]]; }

_hook_after() {
  local input="$1" cmd output url host repo num
  cmd=$(_parse_cmd "$input")
  _is_pr_create "$cmd" || { echo '{}'; return; }
  [[ "$cmd" =~ --dry-run || "$cmd" =~ --assignee ]] && { echo '{}'; return; }
  if echo "$input" | jq -e '.output' >/dev/null 2>&1; then
    output=$(jq -r '.output // empty' <<<"$input")
  else
    output=$(jq -r '.tool_response.stdout // .tool_response.content // empty' <<<"$input")
  fi
  url=$(grep -oE 'https?://[^[:space:]]+/pull/[0-9]+' <<<"$output" | head -1 || true)
  [[ -n "$url" ]] || { echo '{}'; exit 0; }
  [[ "$url" =~ ^https?://([^/]+)/([^/]+/[^/]+)/pull/([0-9]+) ]] || { echo '{}'; exit 0; }
  host="${BASH_REMATCH[1]}"; repo="${BASH_REMATCH[2]}"; num="${BASH_REMATCH[3]}"
  local args=()
  while IFS= read -r login; do [[ -n "$login" ]] && args+=(--add-assignee "$login"); done < <(_assignees_for_host "$host")
  ((${#args[@]})) && GH_HOST="$host" gh pr edit "$num" --repo "$repo" "${args[@]}" >/dev/null 2>&1 || true
  echo '{}'
}

_hook_ask_cursor() {
  local input="$1" cmd
  cmd=$(_parse_cmd "$input")
  _is_pr_create "$cmd" || { echo '{ "permission": "allow" }'; return; }
  [[ "$cmd" =~ --dry-run ]] && { echo '{ "permission": "allow" }'; return; }
  _should_ask || { echo '{ "permission": "allow" }'; return; }
  jq -n --arg um "$(_ask_message)" \
    '{ "permission": "ask", "user_message": $um, "agent_message": "Use gh-pr-roster-json + AskQuestion first." }'
}

_hook_ask_claude() {
  local input="$1" cmd
  cmd=$(_parse_cmd "$input")
  _is_pr_create "$cmd" && ! [[ "$cmd" =~ --dry-run ]] && _should_ask || exit 0
  jq -n --arg reason "$(_ask_message)" \
    '{ "hookSpecificOutput": { "hookEventName": "PreToolUse", "permissionDecision": "ask", "permissionDecisionReason": $reason } }'
}

_hook_session_cursor() {
  [[ -f "$CONFIG" ]] || { echo '{}'; return; }
  [[ "$(jq -r '.agent_ask_before_pr_create // true' "$CONFIG")" == "true" ]] || { echo '{}'; return; }
  local roster
  roster=$(_cmd_roster)
  jq -n --argjson r "$roster" \
    '{ "additional_context": ("Before gh pr create: AskQuestion from gh-pr-roster-json. Roster: " + ($r | tostring)) }'
}

_hook_session_claude() {
  [[ -f "$CONFIG" ]] || exit 0
  [[ "$(jq -r '.agent_ask_before_pr_create // true' "$CONFIG")" == "true" ]] || exit 0
  local roster ctx
  roster=$(_cmd_roster)
  ctx="Before gh pr create: AskUserQuestion from gh-pr-roster-json. Roster: $roster"
  jq -n --arg c "$ctx" \
    '{ "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": $c } }'
}

case "${1:-hook}" in
  roster) _cmd_roster ;;
  create) shift; _cmd_create "$@" ;;
  hook)
    INPUT=$(cat || true)
    case "${HARNESS:-cursor}:${HOOK_MODE:-}" in
      cursor:session) _hook_session_cursor "$INPUT" ;;
      cursor:ask) _hook_ask_cursor "$INPUT" ;;
      cursor:after) _hook_after "$INPUT" ;;
      claude:session) _hook_session_claude "$INPUT" ;;
      claude:ask) _hook_ask_claude "$INPUT" ;;
      claude:after) _hook_after "$INPUT" ;;
      *)
        echo "usage: harness.sh roster|create | HARNESS=cursor HOOK_MODE=session|ask|after harness.sh hook" >&2
        exit 1
        ;;
    esac
    ;;
  *) echo "usage: harness.sh roster|create|hook" >&2; exit 1 ;;
esac