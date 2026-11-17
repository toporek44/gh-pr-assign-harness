# shellcheck shell=bash
# Build user-facing assignee confirm message (shared by Cursor + Claude adapters).
gh_pr_build_ask_message() {
  local CONFIG="${1:-$HOME/.config/gh/pr-default-assignees.json}"
  local ROSTER_BIN="${2:-$HOME/.local/bin/gh-pr-roster-json}"
  local msg defaults roster_line user_msg

  msg=$(jq -r '.agent_ask_message // "Who should be assigned to this PR?"' "$CONFIG" 2>/dev/null || echo "Who should be assigned to this PR?")
  defaults=$(jq -r '[.default_assignees[]?] | join(", ")' "$CONFIG" 2>/dev/null || true)
  roster_line=""
  if [[ -x "$ROSTER_BIN" ]]; then
    roster_line=$("$ROSTER_BIN" 2>/dev/null | jq -r '[.options[0:3][].label] | join(" | ")' 2>/dev/null || true)
  fi
  user_msg="$msg"
  if [[ -n "$defaults" ]]; then
    user_msg="$msg Default assignees: $defaults."
  fi
  user_msg="$user_msg Confirm assignees (or reject and use gh-pr-roster-json + AskQuestion first)."
  if [[ -n "$roster_line" ]]; then
    user_msg="$user_msg Picker: $roster_line"
  fi
  printf '%s' "$user_msg"
}

gh_pr_should_ask_before_create() {
  local CONFIG="${1:-$HOME/.config/gh/pr-default-assignees.json}"
  if [[ ! -f "$CONFIG" ]]; then
    return 0
  fi
  [[ "$(jq -r '.agent_ask_before_pr_create // true' "$CONFIG")" == "true" ]] && return 0
  [[ "$(jq -r '.shell_ask_before_pr_create // false' "$CONFIG")" == "true" ]] && return 0
  return 1
}