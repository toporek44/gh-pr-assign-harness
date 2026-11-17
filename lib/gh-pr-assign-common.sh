# shellcheck shell=bash
GH_PR_ASSIGNEES_CONFIG="${GH_PR_ASSIGNEES_CONFIG:-$HOME/.config/gh/pr-default-assignees.json}"

gh_pr_assignees_for_host() {
  local host="${1:-github.com}"
  if [[ ! -f "$GH_PR_ASSIGNEES_CONFIG" ]]; then
    return 0
  fi
  jq -r --arg h "$host" '
    if (.hosts[$h].assignees | length) > 0 then .hosts[$h].assignees[]
    else .default_assignees[]? // empty
    end
  ' "$GH_PR_ASSIGNEES_CONFIG"
}

gh_pr_build_assignee_args() {
  local host="$1"
  local login
  while IFS= read -r login; do
    [[ -n "$login" ]] || continue
    printf '%s\n' "--assignee" "$login"
  done < <(gh_pr_assignees_for_host "$host")
}

gh_pr_parse_pull_url() {
  local url="$1"
  if [[ "$url" =~ ^https?://([^/]+)/([^/]+/[^/]+)/pull/([0-9]+)/?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    return 0
  fi
  return 1
}

gh_pr_add_default_assignees() {
  local host="$1"
  local repo="$2"
  local number="$3"
  local args=()
  local login
  while IFS= read -r login; do
    [[ -n "$login" ]] || continue
    args+=(--add-assignee "$login")
  done < <(gh_pr_assignees_for_host "$host")
  if ((${#args[@]} == 0)); then
    return 0
  fi
  GH_HOST="$host" gh pr edit "$number" --repo "$repo" "${args[@]}" >/dev/null 2>&1 || true
}

gh_pr_harness_root() {
  if [[ -n "${GH_PR_ASSIGN_ROOT:-}" && -d "$GH_PR_ASSIGN_ROOT" ]]; then
    printf '%s\n' "$GH_PR_ASSIGN_ROOT"
    return 0
  fi
  local d
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  printf '%s\n' "$d"
}