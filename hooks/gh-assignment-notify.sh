#!/usr/bin/env bash
# optional LaunchAgent: macOS notification on new assign
set -euo pipefail
STATE_DIR="${HOME}/.cache/gh-assignment-notify"
STATE_FILE="${STATE_DIR}/notified-ids.json"
SEED_FILE="${STATE_DIR}/.seeded"
CONFIG="${HOME}/.config/gh/pr-default-assignees.json"
mkdir -p "$STATE_DIR"
command -v jq >/dev/null 2>&1 || exit 0
[[ -f "$STATE_FILE" ]] || echo '[]' >"$STATE_FILE"
notify_mac() {
  local title="$1" subtitle="$2"
  command -v osascript >/dev/null 2>&1 || return
  osascript -e "display notification \"${subtitle//\"/\\\"}\" with title \"${title//\"/\\\"}\" sound name \"Glass\"" 2>/dev/null || true
}
is_notified() { jq -e --arg id "$1" 'index($id) != null' "$STATE_FILE" >/dev/null 2>&1; }
append_ids() {
  jq --argjson add "$1" '. + $add | unique' "$STATE_FILE" >"${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}
hosts=()
if [[ -f "$CONFIG" ]]; then
  while IFS= read -r line; do hosts+=("$line"); done < <(jq -r '.notify_hosts[]? | .host + ":" + .login' "$CONFIG" 2>/dev/null || true)
fi
if ((${#hosts[@]} == 0)); then hosts=("git.dev.box.net:mtopor" "github.com:toporek44"); fi
collect() { GH_HOST="$1"; gh api notifications 2>/dev/null | jq -c '.[] | select(.reason == "assign")' 2>/dev/null || true; }
if [[ ! -f "$SEED_FILE" ]]; then
  seed=()
  for entry in "${hosts[@]}"; do
    h="${entry%%:*}"
    while IFS= read -r line; do [[ -n "$line" ]] && seed+=("$(jq -r .id <<<"$line")"); done < <(collect "$h")
  done
  ((${#seed[@]})) && append_ids "$(printf '%s\n' "${seed[@]}" | jq -R . | jq -s .)"
  touch "$SEED_FILE"; exit 0
fi
new=()
for entry in "${hosts[@]}"; do
  h="${entry%%:*}"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    id=$(jq -r '.id' <<<"$line")
    title=$(jq -r '.subject.title // "Pull request"' <<<"$line")
    is_notified "$id" && continue
    notify_mac "PR assigned ($h)" "$title"
    new+=("$id")
  done < <(collect "$h")
done
((${#new[@]})) && append_ids "$(printf '%s\n' "${new[@]}" | jq -R . | jq -s .)"